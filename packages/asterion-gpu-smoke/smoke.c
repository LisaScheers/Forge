#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl31.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void fail(const char *message)
{
    fprintf(stderr, "FAIL: %s\n", message);
    exit(EXIT_FAILURE);
}

static void check_gl(const char *operation)
{
    GLenum error = glGetError();
    if (error != GL_NO_ERROR) {
        fprintf(stderr, "FAIL: %s: GL error %#x\n", operation, error);
        exit(EXIT_FAILURE);
    }
}

static void check_egl(EGLBoolean result, const char *operation)
{
    if (result != EGL_TRUE) {
        fprintf(stderr, "FAIL: %s: EGL error %#x\n", operation, eglGetError());
        exit(EXIT_FAILURE);
    }
}

static GLuint compile(GLenum stage, const char *source)
{
    GLuint shader = glCreateShader(stage);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char log[4096];
        glGetShaderInfoLog(shader, sizeof(log), NULL, log);
        fprintf(stderr, "FAIL: shader compile: %s\n", log);
        exit(EXIT_FAILURE);
    }
    check_gl("compile shader");
    return shader;
}

static GLuint link_program(const GLuint *shaders, size_t count)
{
    GLuint program = glCreateProgram();
    for (size_t i = 0; i < count; ++i)
        glAttachShader(program, shaders[i]);
    glLinkProgram(program);
    GLint success;
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) {
        char log[4096];
        glGetProgramInfoLog(program, sizeof(log), NULL, log);
        fprintf(stderr, "FAIL: program link: %s\n", log);
        exit(EXIT_FAILURE);
    }
    for (size_t i = 0; i < count; ++i)
        glDeleteShader(shaders[i]);
    check_gl("link program");
    return program;
}

static void check_pixel(GLint x, GLint y, const GLubyte expected[4])
{
    GLubyte actual[4] = {0};
    glReadPixels(x, y, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, actual);
    check_gl("read raster pixel");
    if (memcmp(actual, expected, 4)) {
        fprintf(stderr, "FAIL: pixel (%d,%d): got %u,%u,%u,%u; expected %u,%u,%u,%u\n",
                x, y, actual[0], actual[1], actual[2], actual[3],
                expected[0], expected[1], expected[2], expected[3]);
        exit(EXIT_FAILURE);
    }
}

static void check_graphics(void)
{
    const char *vertex =
        "#version 310 es\n"
        "const vec2 p[3] = vec2[3](vec2(-1,-1), vec2(1,-1), vec2(-1,1));\n"
        "void main() { gl_Position = vec4(p[gl_VertexID], 0, 1); }\n";
    const char *fragment =
        "#version 310 es\n"
        "precision highp float;\n"
        "layout(location=0) out vec4 color;\n"
        "void main() { color = vec4(1, 0, 0, 1); }\n";
    const GLuint shaders[] = {compile(GL_VERTEX_SHADER, vertex),
                              compile(GL_FRAGMENT_SHADER, fragment)};
    GLuint program = link_program(shaders, 2);
    GLuint vao;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    glViewport(0, 0, 64, 64);
    glDisable(GL_DITHER);
    glClearColor(0, 0, 1, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(program);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glFinish();
    check_gl("draw triangle");
    const GLubyte red[] = {255, 0, 0, 255};
    const GLubyte blue[] = {0, 0, 255, 255};
    check_pixel(8, 8, red);
    check_pixel(24, 8, red);
    check_pixel(8, 24, red);
    check_pixel(56, 56, blue);
    check_pixel(40, 56, blue);
    check_pixel(56, 40, blue);
    glDeleteVertexArrays(1, &vao);
    glDeleteProgram(program);
    check_gl("release graphics objects");
    puts("PASS: raster triangle: 6 exact RGBA pixel readbacks");
}

static void check_compute(void)
{
    const char *source =
        "#version 310 es\n"
        "layout(local_size_x=8) in;\n"
        "layout(std430, binding=0) buffer Result { uint value[]; };\n"
        "void main() { uint i = gl_GlobalInvocationID.x;\n"
        "  value[i] = (i * 17u) ^ 0x5a5a1234u; }\n";
    GLuint shader = compile(GL_COMPUTE_SHADER, source);
    GLuint program = link_program(&shader, 1);
    uint32_t initial[32];
    for (size_t i = 0; i < 32; ++i)
        initial[i] = UINT32_C(0xdeadbeef);
    GLuint buffer;
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, buffer);
    glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(initial), initial, GL_DYNAMIC_READ);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, buffer);
    glUseProgram(program);
    glDispatchCompute(4, 1, 1);
    glMemoryBarrier(GL_BUFFER_UPDATE_BARRIER_BIT | GL_SHADER_STORAGE_BARRIER_BIT);
    glFinish();
    check_gl("dispatch compute shader");
    const uint32_t *actual = glMapBufferRange(GL_SHADER_STORAGE_BUFFER, 0,
                                             sizeof(initial), GL_MAP_READ_BIT);
    check_gl("map compute result");
    if (!actual)
        fail("compute result is not mapped");
    for (uint32_t i = 0; i < 32; ++i) {
        uint32_t expected = (i * 17u) ^ UINT32_C(0x5a5a1234);
        if (actual[i] != expected) {
            fprintf(stderr, "FAIL: compute[%u]: got %#x; expected %#x\n",
                    i, actual[i], expected);
            exit(EXIT_FAILURE);
        }
    }
    if (!glUnmapBuffer(GL_SHADER_STORAGE_BUFFER))
        fail("compute result became invalid");
    glDeleteBuffers(1, &buffer);
    glDeleteProgram(program);
    check_gl("release compute objects");
    puts("PASS: compute shader: 32 exact integer readbacks");
}

int main(int argc, char **argv)
{
    bool allow_software = argc == 2 && !strcmp(argv[1], "--allow-software");
    if (argc != 1 && !allow_software) {
        fprintf(stderr, "Usage: %s [--allow-software]\n", argv[0]);
        return EXIT_FAILURE;
    }
    EGLDisplay display = eglGetPlatformDisplay(EGL_PLATFORM_SURFACELESS_MESA,
                                               EGL_DEFAULT_DISPLAY, NULL);
    if (display == EGL_NO_DISPLAY)
        fail("no surfaceless EGL display");
    EGLint major, minor;
    check_egl(eglInitialize(display, &major, &minor), "initialize EGL");
    check_egl(eglBindAPI(EGL_OPENGL_ES_API), "select GLES API");
    const EGLint attributes[] = {
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_NONE};
    EGLConfig config;
    EGLint count;
    check_egl(eglChooseConfig(display, attributes, &config, 1, &count), "choose EGL config");
    if (count != 1)
        fail("no RGBA8 GLES3 pbuffer config");
    const EGLint context_attributes[] = {
        EGL_CONTEXT_MAJOR_VERSION, 3, EGL_CONTEXT_MINOR_VERSION, 1, EGL_NONE};
    EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attributes);
    if (context == EGL_NO_CONTEXT)
        fail("could not create GLES 3.1 context");
    const EGLint surface_attributes[] = {EGL_WIDTH, 64, EGL_HEIGHT, 64, EGL_NONE};
    EGLSurface surface = eglCreatePbufferSurface(display, config, surface_attributes);
    if (surface == EGL_NO_SURFACE)
        fail("could not create pbuffer");
    check_egl(eglMakeCurrent(display, surface, surface, context), "make EGL context current");
    const char *renderer = (const char *)glGetString(GL_RENDERER);
    const char *version = (const char *)glGetString(GL_VERSION);
    check_gl("query renderer");
    if (!renderer || !version)
        fail("missing GL renderer/version");
    printf("EGL: %d.%d\nRenderer: %s\nAPI: %s\n", major, minor, renderer, version);
    bool hardware = strstr(renderer, "Apple M3 Pro") && strstr(renderer, "G15S");
    bool software = strstr(renderer, "llvmpipe") || strstr(renderer, "softpipe");
    if (!hardware && !(allow_software && software))
        fail("expected Apple M3 Pro (G15S); refusing another renderer");
    if (!hardware)
        puts("SOFTWARE ORACLE: this run does not establish M3 Pro hardware support");
    check_graphics();
    check_compute();
    check_egl(eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT),
              "release EGL context");
    check_egl(eglDestroySurface(display, surface), "destroy EGL surface");
    check_egl(eglDestroyContext(display, context), "destroy EGL context");
    check_egl(eglTerminate(display), "terminate EGL");
    puts(hardware ? "PASS: M3 Pro hardware graphics and compute smoke test"
                  : "PASS: software oracle only");
    return EXIT_SUCCESS;
}
