# SurfacePeeler
Version 2 of the macro to extract the surface layer of 3D volumetric images

This macro will take a sinlge or multi channel image, and generate a mask following the upper surface of a 3D volumetric image.

The mask can be positioned any height above or below the upper surface & can be any number of pixels thick.

The mask moves up or down perpendicular to the surface following the local surface geometry.

### Step 1 Threshold the image - choose a filter (Gaussian, Median etc) and threshold algorithm
<img src="Images/001%20Combined%20multi%20channel%20image%20to%20threshold.JPG" width=50% height=50%>

### Step 2 Check the threshold gives an acceptable surface - if not change parameters to repeat
<img src="Images/002%20Check%20thresholding%20finds%20surface.JPG" width=50% height=50%>

You can zoom in and scroll through the slices to check the threshold gives a good surface
Don't worry if it isn't perfect, you can move it up or down and set it any thickness later...

<img src="Images/004a%20Zoom%20in%20on%20surface.JPG" width=50% height=50%>

You are asked whether you want to repeat the step or proceed

<img src="Images/003%20re-try%20threshold%20or%20proceed.JPG" width=50% height=50%>
