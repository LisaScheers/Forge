#include <vulkan/vulkan.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "shaders.h"

enum { WIDTH = 64, HEIGHT = 64, VALUES = 32 };

static VkPhysicalDevice physical;
static VkDevice device;

static void fail(const char *message)
{
    fprintf(stderr, "FAIL: %s\n", message);
    exit(EXIT_FAILURE);
}

static void check(VkResult result, const char *operation)
{
    if (result != VK_SUCCESS) {
        fprintf(stderr, "FAIL: %s: VkResult %d\n", operation, result);
        exit(EXIT_FAILURE);
    }
}

static uint32_t memory_type(uint32_t bits, VkMemoryPropertyFlags required)
{
    VkPhysicalDeviceMemoryProperties properties;
    vkGetPhysicalDeviceMemoryProperties(physical, &properties);
    for (uint32_t index = 0; index < properties.memoryTypeCount; ++index)
        if ((bits & (1u << index)) &&
            (properties.memoryTypes[index].propertyFlags & required) == required)
            return index;
    fail("no memory type with required properties");
    return 0;
}

struct buffer {
    VkBuffer object;
    VkDeviceMemory memory;
    void *mapped;
};

static struct buffer create_buffer(VkDeviceSize size, VkBufferUsageFlags usage)
{
    struct buffer buffer;
    const VkBufferCreateInfo info = {
        .sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = size, .usage = usage, .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
    };
    check(vkCreateBuffer(device, &info, NULL, &buffer.object), "create buffer");
    VkMemoryRequirements requirements;
    vkGetBufferMemoryRequirements(device, buffer.object, &requirements);
    const VkMemoryAllocateInfo allocation = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = requirements.size,
        .memoryTypeIndex = memory_type(requirements.memoryTypeBits, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT),
    };
    check(vkAllocateMemory(device, &allocation, NULL, &buffer.memory), "allocate buffer memory");
    check(vkBindBufferMemory(device, buffer.object, buffer.memory, 0), "bind buffer memory");
    check(vkMapMemory(device, buffer.memory, 0, VK_WHOLE_SIZE, 0, &buffer.mapped), "map buffer");
    return buffer;
}

static void flush_buffer(struct buffer buffer)
{
    const VkMappedMemoryRange range = {
        .sType = VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
        .memory = buffer.memory, .offset = 0, .size = VK_WHOLE_SIZE,
    };
    check(vkFlushMappedMemoryRanges(device, 1, &range), "flush host buffer");
}

static void invalidate_buffer(struct buffer buffer)
{
    const VkMappedMemoryRange range = {
        .sType = VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
        .memory = buffer.memory, .offset = 0, .size = VK_WHOLE_SIZE,
    };
    check(vkInvalidateMappedMemoryRanges(device, 1, &range), "invalidate GPU result");
}

static void destroy_buffer(struct buffer buffer)
{
    vkUnmapMemory(device, buffer.memory);
    vkDestroyBuffer(device, buffer.object, NULL);
    vkFreeMemory(device, buffer.memory, NULL);
}

static VkShaderModule create_shader(const uint32_t *code, size_t size)
{
    VkShaderModule shader;
    const VkShaderModuleCreateInfo info = {
        .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = size, .pCode = code,
    };
    check(vkCreateShaderModule(device, &info, NULL, &shader), "create shader module");
    return shader;
}

static void check_pixel(const uint8_t *image, uint32_t x, uint32_t y, const uint8_t expected[4])
{
    const uint8_t *actual = image + (y * WIDTH + x) * 4;
    if (memcmp(actual, expected, 4)) {
        fprintf(stderr, "FAIL: Vulkan pixel (%u,%u): got %u,%u,%u,%u; expected %u,%u,%u,%u\n",
                x, y, actual[0], actual[1], actual[2], actual[3],
                expected[0], expected[1], expected[2], expected[3]);
        exit(EXIT_FAILURE);
    }
}

int main(int argc, char **argv)
{
    const bool allow_software = argc == 2 && !strcmp(argv[1], "--allow-software");
    if (argc != 1 && !allow_software) {
        fprintf(stderr, "Usage: %s [--allow-software]\n", argv[0]);
        return EXIT_FAILURE;
    }
    setvbuf(stdout, NULL, _IOLBF, 0);
    const VkApplicationInfo application = {
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Asterion Vulkan smoke", .apiVersion = VK_API_VERSION_1_0,
    };
    const VkInstanceCreateInfo instance_info = {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO, .pApplicationInfo = &application,
    };
    VkInstance instance;
    check(vkCreateInstance(&instance_info, NULL, &instance), "create instance");
    uint32_t count = 0;
    check(vkEnumeratePhysicalDevices(instance, &count, NULL), "enumerate physical device count");
    if (!count)
        fail("no Vulkan physical device");
    VkPhysicalDevice *devices = calloc(count, sizeof(*devices));
    if (!devices)
        fail("allocate physical device list");
    check(vkEnumeratePhysicalDevices(instance, &count, devices), "enumerate physical devices");
    bool hardware = false;
    for (uint32_t index = 0; index < count; ++index) {
        VkPhysicalDeviceProperties properties;
        vkGetPhysicalDeviceProperties(devices[index], &properties);
        bool apple = strstr(properties.deviceName, "Apple M3 Pro") &&
                     strstr(properties.deviceName, "G15S") &&
                     properties.deviceType != VK_PHYSICAL_DEVICE_TYPE_CPU;
        bool software = properties.deviceType == VK_PHYSICAL_DEVICE_TYPE_CPU &&
                        (strstr(properties.deviceName, "llvmpipe") ||
                         strstr(properties.deviceName, "lavapipe"));
        printf("Vulkan device: %s; vendor %#x, device %#x, API %u.%u.%u, type %u\n",
               properties.deviceName, properties.vendorID, properties.deviceID,
               VK_API_VERSION_MAJOR(properties.apiVersion), VK_API_VERSION_MINOR(properties.apiVersion),
               VK_API_VERSION_PATCH(properties.apiVersion), properties.deviceType);
        if (apple || (allow_software && software && physical == VK_NULL_HANDLE)) {
            physical = devices[index];
            hardware = apple;
            if (apple)
                break;
        }
    }
    free(devices);
    if (physical == VK_NULL_HANDLE)
        fail("expected Apple M3 Pro (G15S); refusing another Vulkan device");
    if (!hardware)
        puts("SOFTWARE ORACLE: this run does not establish M3 Pro hardware support");

    uint32_t family_count = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(physical, &family_count, NULL);
    VkQueueFamilyProperties *families = calloc(family_count, sizeof(*families));
    if (!families)
        fail("allocate queue family list");
    vkGetPhysicalDeviceQueueFamilyProperties(physical, &family_count, families);
    uint32_t family = UINT32_MAX;
    for (uint32_t index = 0; index < family_count; ++index)
        if (families[index].queueCount &&
            (families[index].queueFlags & (VK_QUEUE_GRAPHICS_BIT | VK_QUEUE_COMPUTE_BIT)) ==
            (VK_QUEUE_GRAPHICS_BIT | VK_QUEUE_COMPUTE_BIT)) {
            family = index;
            break;
        }
    free(families);
    if (family == UINT32_MAX)
        fail("no combined graphics/compute queue family");
    const float priority = 1.0f;
    const VkDeviceQueueCreateInfo queue_info = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = family, .queueCount = 1, .pQueuePriorities = &priority,
    };
    const VkDeviceCreateInfo device_info = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = 1, .pQueueCreateInfos = &queue_info,
    };
    check(vkCreateDevice(physical, &device_info, NULL, &device), "create device");
    VkQueue queue;
    vkGetDeviceQueue(device, family, 0, &queue);

    struct buffer pixels = create_buffer(WIDTH * HEIGHT * 4, VK_BUFFER_USAGE_TRANSFER_DST_BIT);
    struct buffer values = create_buffer(VALUES * sizeof(uint32_t), VK_BUFFER_USAGE_STORAGE_BUFFER_BIT);
    memset(pixels.mapped, 0, WIDTH * HEIGHT * 4);
    uint32_t *integers = values.mapped;
    for (uint32_t index = 0; index < VALUES; ++index)
        integers[index] = UINT32_C(0xdeadbeef);
    flush_buffer(pixels);
    flush_buffer(values);

    VkImage image;
    const VkImageCreateInfo image_info = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO, .imageType = VK_IMAGE_TYPE_2D,
        .format = VK_FORMAT_R8G8B8A8_UNORM, .extent = {WIDTH, HEIGHT, 1},
        .mipLevels = 1, .arrayLayers = 1, .samples = VK_SAMPLE_COUNT_1_BIT,
        .tiling = VK_IMAGE_TILING_OPTIMAL,
        .usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
        .sharingMode = VK_SHARING_MODE_EXCLUSIVE, .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
    };
    check(vkCreateImage(device, &image_info, NULL, &image), "create render image");
    VkMemoryRequirements requirements;
    vkGetImageMemoryRequirements(device, image, &requirements);
    const VkMemoryAllocateInfo image_allocation = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO, .allocationSize = requirements.size,
        .memoryTypeIndex = memory_type(requirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT),
    };
    VkDeviceMemory image_memory;
    check(vkAllocateMemory(device, &image_allocation, NULL, &image_memory), "allocate image memory");
    check(vkBindImageMemory(device, image, image_memory, 0), "bind image memory");
    const VkImageViewCreateInfo view_info = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = image, .viewType = VK_IMAGE_VIEW_TYPE_2D, .format = VK_FORMAT_R8G8B8A8_UNORM,
        .subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1},
    };
    VkImageView view;
    check(vkCreateImageView(device, &view_info, NULL, &view), "create image view");

    const VkAttachmentDescription attachment = {
        .format = VK_FORMAT_R8G8B8A8_UNORM, .samples = VK_SAMPLE_COUNT_1_BIT,
        .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR, .storeOp = VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE, .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED, .finalLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
    };
    const VkAttachmentReference reference = {0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL};
    const VkSubpassDescription subpass = {
        .pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1, .pColorAttachments = &reference,
    };
    const VkSubpassDependency dependencies[] = {
        {.srcSubpass = VK_SUBPASS_EXTERNAL, .dstSubpass = 0,
         .srcStageMask = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
         .dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
         .dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT},
        {.srcSubpass = 0, .dstSubpass = VK_SUBPASS_EXTERNAL,
         .srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
         .dstStageMask = VK_PIPELINE_STAGE_TRANSFER_BIT,
         .srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT, .dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT},
    };
    const VkRenderPassCreateInfo render_info = {
        .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1, .pAttachments = &attachment,
        .subpassCount = 1, .pSubpasses = &subpass,
        .dependencyCount = 2, .pDependencies = dependencies,
    };
    VkRenderPass render_pass;
    check(vkCreateRenderPass(device, &render_info, NULL, &render_pass), "create render pass");
    const VkFramebufferCreateInfo framebuffer_info = {
        .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO, .renderPass = render_pass,
        .attachmentCount = 1, .pAttachments = &view, .width = WIDTH, .height = HEIGHT, .layers = 1,
    };
    VkFramebuffer framebuffer;
    check(vkCreateFramebuffer(device, &framebuffer_info, NULL, &framebuffer), "create framebuffer");
    VkShaderModule vertex = create_shader(vertex_spirv, sizeof(vertex_spirv));
    VkShaderModule fragment = create_shader(fragment_spirv, sizeof(fragment_spirv));
    VkShaderModule compute = create_shader(compute_spirv, sizeof(compute_spirv));
    const VkPipelineShaderStageCreateInfo graphics_stages[] = {
        {.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
         .stage = VK_SHADER_STAGE_VERTEX_BIT, .module = vertex, .pName = "main"},
        {.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
         .stage = VK_SHADER_STAGE_FRAGMENT_BIT, .module = fragment, .pName = "main"},
    };
    const VkPipelineVertexInputStateCreateInfo vertex_input = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    };
    const VkPipelineInputAssemblyStateCreateInfo assembly = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
    };
    const VkViewport viewport = {0, 0, WIDTH, HEIGHT, 0, 1};
    const VkRect2D scissor = {{0, 0}, {WIDTH, HEIGHT}};
    const VkPipelineViewportStateCreateInfo viewport_state = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1, .pViewports = &viewport, .scissorCount = 1, .pScissors = &scissor,
    };
    const VkPipelineRasterizationStateCreateInfo rasterization = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .polygonMode = VK_POLYGON_MODE_FILL, .cullMode = VK_CULL_MODE_NONE,
        .frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE, .lineWidth = 1.0f,
    };
    const VkPipelineMultisampleStateCreateInfo multisample = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .rasterizationSamples = VK_SAMPLE_COUNT_1_BIT,
    };
    const VkPipelineColorBlendAttachmentState blend_attachment = {
        .colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
                          VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT,
    };
    const VkPipelineColorBlendStateCreateInfo blend = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .attachmentCount = 1, .pAttachments = &blend_attachment,
    };
    const VkPipelineLayoutCreateInfo graphics_layout_info = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    };
    VkPipelineLayout graphics_layout;
    check(vkCreatePipelineLayout(device, &graphics_layout_info, NULL, &graphics_layout), "create graphics layout");
    const VkGraphicsPipelineCreateInfo graphics_info = {
        .sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = 2, .pStages = graphics_stages, .pVertexInputState = &vertex_input,
        .pInputAssemblyState = &assembly, .pViewportState = &viewport_state,
        .pRasterizationState = &rasterization, .pMultisampleState = &multisample,
        .pColorBlendState = &blend, .layout = graphics_layout, .renderPass = render_pass, .subpass = 0,
    };
    VkPipeline graphics_pipeline;
    check(vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &graphics_info, NULL, &graphics_pipeline), "create graphics pipeline");

    const VkDescriptorSetLayoutBinding binding = {
        .binding = 0, .descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        .descriptorCount = 1, .stageFlags = VK_SHADER_STAGE_COMPUTE_BIT,
    };
    const VkDescriptorSetLayoutCreateInfo descriptor_layout_info = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = 1, .pBindings = &binding,
    };
    VkDescriptorSetLayout descriptor_layout;
    check(vkCreateDescriptorSetLayout(device, &descriptor_layout_info, NULL, &descriptor_layout), "create descriptor layout");
    const VkPipelineLayoutCreateInfo compute_layout_info = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1, .pSetLayouts = &descriptor_layout,
    };
    VkPipelineLayout compute_layout;
    check(vkCreatePipelineLayout(device, &compute_layout_info, NULL, &compute_layout), "create compute layout");
    const VkComputePipelineCreateInfo compute_info = {
        .sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .stage = {.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                  .stage = VK_SHADER_STAGE_COMPUTE_BIT, .module = compute, .pName = "main"},
        .layout = compute_layout,
    };
    VkPipeline compute_pipeline;
    check(vkCreateComputePipelines(device, VK_NULL_HANDLE, 1, &compute_info, NULL, &compute_pipeline), "create compute pipeline");
    const VkDescriptorPoolSize pool_size = {VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1};
    const VkDescriptorPoolCreateInfo pool_info = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .maxSets = 1, .poolSizeCount = 1, .pPoolSizes = &pool_size,
    };
    VkDescriptorPool descriptor_pool;
    check(vkCreateDescriptorPool(device, &pool_info, NULL, &descriptor_pool), "create descriptor pool");
    const VkDescriptorSetAllocateInfo descriptor_info = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = descriptor_pool, .descriptorSetCount = 1, .pSetLayouts = &descriptor_layout,
    };
    VkDescriptorSet descriptor;
    check(vkAllocateDescriptorSets(device, &descriptor_info, &descriptor), "allocate descriptor set");
    const VkDescriptorBufferInfo buffer_info = {values.object, 0, VALUES * sizeof(uint32_t)};
    const VkWriteDescriptorSet write = {
        .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dstSet = descriptor, .dstBinding = 0, .descriptorCount = 1,
        .descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .pBufferInfo = &buffer_info,
    };
    vkUpdateDescriptorSets(device, 1, &write, 0, NULL);

    const VkCommandPoolCreateInfo command_pool_info = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO, .queueFamilyIndex = family,
    };
    VkCommandPool command_pool;
    check(vkCreateCommandPool(device, &command_pool_info, NULL, &command_pool), "create command pool");
    const VkCommandBufferAllocateInfo command_info = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, .commandPool = command_pool,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY, .commandBufferCount = 1,
    };
    VkCommandBuffer command;
    check(vkAllocateCommandBuffers(device, &command_info, &command), "allocate command buffer");
    const VkCommandBufferBeginInfo begin_info = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };
    check(vkBeginCommandBuffer(command, &begin_info), "begin command buffer");
    const VkClearValue clear = {.color = {.float32 = {0, 0, 1, 1}}};
    const VkRenderPassBeginInfo render_begin = {
        .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO, .renderPass = render_pass,
        .framebuffer = framebuffer, .renderArea = {{0, 0}, {WIDTH, HEIGHT}},
        .clearValueCount = 1, .pClearValues = &clear,
    };
    vkCmdBeginRenderPass(command, &render_begin, VK_SUBPASS_CONTENTS_INLINE);
    vkCmdBindPipeline(command, VK_PIPELINE_BIND_POINT_GRAPHICS, graphics_pipeline);
    vkCmdDraw(command, 3, 1, 0, 0);
    vkCmdEndRenderPass(command);
    const VkBufferImageCopy copy = {
        .imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1},
        .imageExtent = {WIDTH, HEIGHT, 1},
    };
    vkCmdCopyImageToBuffer(command, image, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, pixels.object, 1, &copy);
    vkCmdBindPipeline(command, VK_PIPELINE_BIND_POINT_COMPUTE, compute_pipeline);
    vkCmdBindDescriptorSets(command, VK_PIPELINE_BIND_POINT_COMPUTE, compute_layout, 0, 1, &descriptor, 0, NULL);
    vkCmdDispatch(command, VALUES / 8, 1, 1);
    const VkMemoryBarrier host_barrier = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_BARRIER,
        .srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT | VK_ACCESS_SHADER_WRITE_BIT,
        .dstAccessMask = VK_ACCESS_HOST_READ_BIT,
    };
    vkCmdPipelineBarrier(command, VK_PIPELINE_STAGE_TRANSFER_BIT | VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                         VK_PIPELINE_STAGE_HOST_BIT, 0, 1, &host_barrier, 0, NULL, 0, NULL);
    check(vkEndCommandBuffer(command), "end command buffer");
    const VkFenceCreateInfo fence_info = {.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
    VkFence fence;
    check(vkCreateFence(device, &fence_info, NULL, &fence), "create completion fence");
    const VkSubmitInfo submit = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO, .commandBufferCount = 1, .pCommandBuffers = &command,
    };
    check(vkQueueSubmit(queue, 1, &submit, fence), "submit graphics and compute work");
    check(vkWaitForFences(device, 1, &fence, VK_TRUE, UINT64_C(10000000000)), "wait for graphics and compute (10 second deadline)");
    invalidate_buffer(pixels);
    invalidate_buffer(values);
    const uint8_t red[] = {255, 0, 0, 255}, blue[] = {0, 0, 255, 255};
    check_pixel(pixels.mapped, 8, 8, red);
    check_pixel(pixels.mapped, 24, 8, red);
    check_pixel(pixels.mapped, 8, 24, red);
    check_pixel(pixels.mapped, 56, 56, blue);
    check_pixel(pixels.mapped, 40, 56, blue);
    check_pixel(pixels.mapped, 56, 40, blue);
    puts("PASS: Vulkan raster triangle: 6 exact RGBA pixel readbacks");
    for (uint32_t index = 0; index < VALUES; ++index) {
        uint32_t expected = (index * 17u) ^ UINT32_C(0x5a5a1234);
        if (integers[index] != expected) {
            fprintf(stderr, "FAIL: Vulkan compute[%u]: got %#x; expected %#x\n", index, integers[index], expected);
            exit(EXIT_FAILURE);
        }
    }
    puts("PASS: Vulkan compute shader: 32 exact integer readbacks");

    vkDestroyFence(device, fence, NULL);
    vkDestroyCommandPool(device, command_pool, NULL);
    vkDestroyDescriptorPool(device, descriptor_pool, NULL);
    vkDestroyPipeline(device, compute_pipeline, NULL);
    vkDestroyPipelineLayout(device, compute_layout, NULL);
    vkDestroyDescriptorSetLayout(device, descriptor_layout, NULL);
    vkDestroyPipeline(device, graphics_pipeline, NULL);
    vkDestroyPipelineLayout(device, graphics_layout, NULL);
    vkDestroyShaderModule(device, compute, NULL);
    vkDestroyShaderModule(device, fragment, NULL);
    vkDestroyShaderModule(device, vertex, NULL);
    vkDestroyFramebuffer(device, framebuffer, NULL);
    vkDestroyRenderPass(device, render_pass, NULL);
    vkDestroyImageView(device, view, NULL);
    vkDestroyImage(device, image, NULL);
    vkFreeMemory(device, image_memory, NULL);
    destroy_buffer(values);
    destroy_buffer(pixels);
    vkDestroyDevice(device, NULL);
    vkDestroyInstance(instance, NULL);
    puts(hardware ? "PASS: native M3 Pro Vulkan graphics and compute" : "PASS: software Vulkan oracle only");
    return EXIT_SUCCESS;
}
