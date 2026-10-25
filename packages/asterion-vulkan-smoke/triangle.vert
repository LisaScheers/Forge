#version 450
const vec2 position[3] = vec2[3](vec2(-1, -1), vec2(1, -1), vec2(-1, 1));
void main() { gl_Position = vec4(position[gl_VertexIndex], 0, 1); }
