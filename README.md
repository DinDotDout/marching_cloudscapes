# Raymarching Cloudscapes
![Cloudscape](https://github.com/DinDotDout/marching_cloudscapes/assets/60853685/86cebc1a-7ec3-482f-8caa-83ad73ec79d5)

This repository contains the results of my exploration and experimentation with creating realistic cloudscapes using raymarching techniques. Raymarching is a rendering technique to create 3D computer graphics. It's especially useful for rendering volumetric and procedural scenes. While the primary focus is on volumetric clouds, I've also incorporated other effects for a more complete skybox look.

## Project Overview

- **Objective**: Learn and experiment with raymarching to create dynamic and visually appealing cloud formations.
- **Note**: The project started in raw glsl but eventually it was moved to Godot in order to facilitate testing. The focus was not to exploit Godot's capabilities and some more engine niceties could have probably been used. Keep in mind that this is not meant for use and there are many things that could be improved, there are a few that I am already aware of but that was the main goal, to be aware of certain things that I was not at the time of starting.
- **Next Steps**: Although this repository serves as a learning experiment, in the future I may create a separate, more specialized repository for a fully developed clouds and weather system, also including a physically based atmosphere. It will not necessarily be in Godot and it will probably be in a custom Vulkan based render.

## Some Optimizations and Techniques Used

1. **Triangle mesh in Front of the Camera**: The raymarching is done in a triangle mesh in front of the camera with a pixel shader. I utilize the z-buffer to render on top of the scene or skip rendering clouds altogether to eliminate unnecessary calculations.
2. **Stepping Techniques Tested**:
   - Dividing the step size based on distance and view angle: Fewer steps are needed when looking straight up to achieve good looking results due to how we represent the atmosphere and the position.
   - Marching at increasingly larger steps with various variation functions (linear and non-linear) up to a maximum distance.
   - Marching at larger steps initially and refining with smaller steps once a volume is found and going back to the other method once we failed in detecting a volume a certain amount of times (inspired by the Horizon Zero Dawn technique).
3. **Noise Construction**:
   - A 2D map defines surface existence.
   - Smoothmin combined with three layers of noise (Perlin and Worley).
   - Detail noise as erosion selectively applied based on transmittance thresholds or in the last stepping method described when looking for volumes. This is skipped based on the two previous conditions to save us some rendering time.

4. **Flat Distant Clouds**: To simulate distant clouds, a 3D texture is mapped onto the desired sphere radius and a Y scroll is used to simulate changes over time (a 2D texture could also be used).
5. **Dithering and Anti-Aliasing**: I employ dithering techniques along with temporal anti-aliasing to reduce the number of steps needed to maintain quality results.
6. **Ray Sphere Intersection**: In order to render the clouds correctly at each point the intersection with two different sphere had to be calculated (inner sphere and outer sphere), and used starting point and end point of the raymarch in order to skip stepping over empty space. Some cases were no intersections are found also had to be taken into account.
7. **Specific to Godot and this project**: I have used a custom helper addon of my creation [Noise Texture Composer](https://github.com/DinDotDout/noise_texture_composer), in order to combine noise textures into a single one to reduce the amount of texture samples needed in the ray marching loop.

There are probably more things that I have forgotten to mention.

## Results

- On a 3440x1440 monitor with an RADEON RX 7700 XT graphics card, 140 fps could be achieved with relative ease with various different uniform setting, although it generally had to be at the cost of rendering distance or looks. Due to the project being for experimentation there was not a goal to achieve better performance for a specific use case, so improvements would need to be done in specific aspects to make it really usable.

## Sources and Inspirations

- [Sebastian Lague's Coding Adventure: Clouds](https://www.youtube.com/watch?v=4QOcCGI6xOU)
- [Simondev's How Big Budget AAA Games Render Clouds](https://www.youtube.com/watch?v=Qj_tK_mdRcA)
- Cloudscapes in Horizon Zero Dawn
- Shadertoy community
- Principles of physically based rendering

Feel free to explore the code and continue experimenting.
