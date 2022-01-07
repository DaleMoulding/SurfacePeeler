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

### Step 3 Set the position of the surface layer to peel
-ve values are above the surface, 0 is the surface, +ve values go below the surface.

Here set at 0 to 4. (From the surface going 4 pixels into the sample)

All displacements are perpendicular to the surface, not just directly vertical.

<img src="Images/004%20set%20surface%20height.JPG" width=33% height=33%>
<img src="Images/004b1 surface set to 0to4pixels.JPG" width=50% height=50%>

You can set this any distance above the surface...  set it to start above the surface and go slightly below...

<img src="Images/004b extract above image.JPG" width=33% height=33%><img src="Images/005 Surface -4 to 4.JPG" width=33% height=33%>

extract a thicker layer...

<img src="Images/007 Surface 0 to 16.JPG" width=33% height=33%>

or any distance and thickness below the surface...

<img src="Images/009 Surface 6 to12.JPG" width=33% height=33%><img src="Images/008 16 to 20.JPG" width=33% height=33%>

### Step 4 Select the image you want to apply the mask to & a layer is peeled from you image
<img src="Images/010 select the image to peel.JPG" width=50% height=50%>
<img src="Images/012 Result and mask.JPG">



