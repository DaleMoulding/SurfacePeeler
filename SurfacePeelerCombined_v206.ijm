// macro released under MIT License MIT License Copyright (c) 2022 DaleMoulding
//See website below for full license details
//https://github.com/DaleMoulding/SurfacePeeler/blob/main/LICENSE


//Surface Peeler All steps 
// v001 Put together the 
// Thresholding
// Erosion to find all surfaces
// Cumulative Z stack to exclude all pixels below a higher surface
// Show orthoviews of the upper surface peelings & the original image as a 2 ch composite
// Orthoviews via Clij2 reslice, to allow interaction with the result

// Take the input image, combine the channels if a mutli-channel and make an 8bit merged single channel image to threshold.
// Makes a new image called: "ForThreshold"

// changelog
// v002 add timers
// v003 keep the Cumulative MaxP & clear memory
// v004 rename the orig image at end of macro
// v005	run porcesses in Batchmode where possible
// v006 add user inpout for Filters, None, Median, mean, Gauss etc.
// v007 add a while loop to proceed only if happy with threhsolding
// v008 add the peeling thickness step
// v009 tidy up timings hide a few windows
// v010 add an option to repeat the peeling thickness 7 placement
// v011 add the final step to apply the peelings
// v012 fix the error where moving the surface up needs to have at least as many pixels moved for the lower region
//******v201
// v201 New method for moving surface levels, use 3D Dilate & 3D erode from Clij2, with an approximation of sphere by iterative dilations / erosions
// Take Robert Haase's idea of sequential dilate in a sphere, then a box to dilate as an octagon. = ~~ a Sphere.
// Adapted this to dilate in step of three. Sphere, Box, Sphere. Better approximation of a Maximal 3D filter. 
// The built in Clij Octagon dilation works well so use that.
// Speed gains are massive. maximum3Dsphere radius 10 takes 20seconds. radius 20 takes 160 seconds...
// iterative dilations 10 pixels = 0.6 sec, 20 pixels = 1 second.
// v202 add print out of filter and theshold used.
// v203 combine channels for final image in the background
// v204 close unneeded windows when finsihed
// v205 Add MIT license and deposit on GitHub
// v206 remove the predefined graphics card for CLIJ2 on lines 355 377 389.


saveSettings(); //save imagej settings , resotre at end of macro

run("Collect Garbage");  // try and clear the RAM

// set up a while condition, so while 'Repeat' is true, you keep trying different thresholds...
	Repeat = true;


setBatchMode(true); //v005 !! remove for test runs 

	print("Surface peeler started. \nMaking a copy of all the channels (if a multi-channel image) to threshold...")

	time1 = getTime(); // start a timer to show processing speed
	
	OrigName = getTitle();
	rename("OrigImage");
	
	Stack.getDimensions(width, height, channels, slices, frames);
	numch = channels
	Stack.setSlice(nSlices/2/numch);
	if (numch>1) Stack.setDisplayMode("composite");
		for (i = 1; i <= numch; i++) {
			Stack.setChannel(i);
			run("Enhance Contrast", "saturated=0.35");
		}
		if (numch >1) {
			run("RGB Color", "slices keep");
			run("8-bit");
			rename("ForThreshold");
		}
		else {
			run("Duplicate...", "title=ForThreshold duplicate");
			run("8-bit");
		}

		time2 = getTime(); 
		print("\nSurface Peeler timings on "+OrigName+"\nProcessed to a merged single channel image for thresholding in "+(time2-time1)/1000+" seconds");
		IJ.freeMemory(); 
		run("Collect Garbage");  // try and clear the RAM

// Keep doing the thresholding until 'Repeat' = false

	while(Repeat){
		

// User inputs. Filters. Threshold. Or its already thresholded? v006

	Dialog.create("Surface Peeler settings");
	Dialog.addMessage("Please enter the filtering and threholding parameters...\n \nif the input is already thresholded press Skip")
	Dialog.addChoice("Filter Type", newArray("Gaussian Blur...", "Median...", "Mean..."), "Gaussian Blur...");
	Dialog.addNumber("Filter Radius", "2");
	Dialog.addChoice("Threshold", newArray("Default", "Huang", "Intermodes", "IsoData", "Li", "MaxEntropy", "Mean", "MinError(I)", "Minimum", "Moments", "Otsu", "Percentile", "RenyiEntropy", "Shanbhag", "Triangle", "Yen"  ), "Default");
	Dialog.addMessage("Skip if already a binary image");
	Dialog.setInsets(5, 80, 0);
	Dialog.addCheckbox("Skip?", false);
	
	Dialog.show();
	Filter = Dialog.getChoice();
	Radius = Dialog.getNumber();
	Threshold = Dialog.getChoice();
	Skip = Dialog.getCheckbox(); //if false do the threshold, if true skip it

	time2 = getTime(); // v009 so timings are correct on repeats

	setBatchMode(true); //v007
		
// Threshold it (filter it first)...

		selectWindow("ForThreshold");						
		setBatchMode("show"); // v005 show this window
	
		if(Skip == false){  // only if it is not already thresholded
		
			run("Duplicate...", "title=Thresholded duplicate");
	
			if(Filter == "Gaussian Blur..."){
				run(Filter, "sigma="+Radius+" stack");
			}
	
			else{
				run(Filter, "radius="+Radius+" stack");
			}
			
			setAutoThreshold(Threshold+" dark stack"); // choose approprite threshold Defaut, Otsu, Huang, tc
			setOption("BlackBackground", false);
			run("Convert to Mask", "method="+Threshold+" background=Dark black"); // Default, Otsu, Huang (In order, less to more thresholded)
		
		}
	
		if(Skip == true) run("Duplicate...", "title=Thresholded duplicate");

		time3 = getTime();											// v008 realised this must be out of the previous loop if skip = true
		print("Filtered ("+Filter+" radius "+Radius+") & thresholded ("+Threshold+") in "+(time3-time2)/1000+" seconds");
		IJ.freeMemory(); 
		run("Collect Garbage");  // try and clear the RAM
	
	// Erode 3D, find differnce. = all surfaces
	// input a thresholded image. Output: New image called "Peelings" = all outer surfaces
	
		selectWindow("Thresholded");
		run("Duplicate...", "title=Eroded duplicate");
		//run("Morphological Filters (3D)", "operation=Erosion element=Ball x-radius=1 y-radius=1 z-radius=1"); // ? try different values??
		run("Erode (3D)", "iso=255"); // much faster?
		//run("Erode (3D)", "iso=255"); // repeat to increase thickness of peelings
		//run("Erode (3D)", "iso=255"); // 
		imageCalculator("Difference create stack", "Thresholded","Eroded");
		rename("Peelings");
	
	// Remove all the peelings except the uppermost layer. 
	// Uses cumulative z-stack, based on SurfCut but faster & more memory efficient as doesn't need to make x new images where x = the number of slices.
	// Surfcut code available here:
	// https://github.com/sverger/SurfCut
		
		selectWindow("Peelings");
		run("Reverse");
		selectWindow("Eroded"); // for new 3D erode version
		run("Reverse");
		 // first two slices
		 setBatchMode(true); // v003 remove to see CumMAxP
		  
			selectWindow("Eroded");  // for new 3D erode version
		    setSlice(1);
		    run("Duplicate...", "title=CumulativeMaxP");
		    selectWindow("Eroded");
		    setSlice(2);
		    run("Duplicate...", "title=2");
			run("Concatenate...", "title=CumulativeMaxP image1=CumulativeMaxP image2=2");
		    run("Z Project...", "projection=[Max Intensity]");
		    rename("Maxsofar");
		 //rest of slices
		 selectWindow("Eroded");
				for (i = 3; i <=nSlices; i++) {  // change to < if using un eroded image to make cumulative maxp
				    setSlice(i);
				    run("Duplicate...", "title=Slice"+i+""); // v001 slow here as too many slices duplicated. 
				   	run("Concatenate...", " title=Maxsofar image1=Maxsofar image2=Slice"+i+"");
				   	run("Z Project...", "projection=[Max Intensity]");
				   	close("Maxsofar");
					selectWindow("MAX_Maxsofar");
					run("Duplicate...", "title=Maxsofar"); // make a copy for the next round
				   	run("Concatenate...", "title=CumulativeMaxP image1=CumulativeMaxP image2=MAX_Maxsofar");
					selectWindow("Eroded");
				}
		
		// take the Cumulative MaxP Image, subtract it from the Eroded Peelings
		
		imageCalculator("Subtract create stack", "Peelings","CumulativeMaxP");
	
		// show the CumulativemaxP outside of batch mode
		selectWindow("CumulativeMaxP");
		run("Reverse");
		setBatchMode("show");
	
		// select the upper surface peelings, reverse it to original orientation & exit batch to see the result
		selectWindow("Result of Peelings");
		rename("UpperSurfacePeelings");
		run("Reverse");
	
		
	
		//selectWindow("Eroded");  //v005 miss out these 3 lines
		//run("Reverse");
		//close();  				//v003 close the eroded window for the talk??
		selectWindow("Peelings");
		run("Reverse");
		selectWindow("UpperSurfacePeelings");
		setBatchMode(false);
	
		time4 = getTime();
		print("Found the upper surface in "+(time4-time3)/1000+" seconds");
		IJ.freeMemory(); 
		run("Collect Garbage");  // try and clear the RAM
	
	// Make a composite image of the merged image to threshold and the upper surface peelings to check the surface identification
	
		run("Merge Channels...", "c1=ForThreshold c2=UpperSurfacePeelings create keep"); // keep the inpt images. Need UpperSurfacePeelings to process orig image
	
		for (i = 1; i <= 2; i++) {
			selectWindow("Composite");
		    Stack.setChannel(i);
		
			run("CLIJ2 Macro Extensions", "cl_device=[]");
			Ext.CLIJ2_clear();
			// reslice left
			Ext.CLIJ2_push("Composite");
			Ext.CLIJ2_resliceLeft("Composite", resliced); //the result is upside down.
			Ext.CLIJ2_pull(resliced);
			
			rename("Resliced"+i);
		}
	
		run("Merge Channels...", "c1=Resliced1 c2=Resliced2 create ignore");
		rename("YZ rotated view");
		Stack.setChannel(1); run("Cyan");
		Stack.setSlice(nSlices/4);					// put it in middle slice and make it bright.
		run("Enhance Contrast", "saturated=0.35");
		Stack.setChannel(2); run("Magenta");
		run("Flip Vertically");
	
		//v004 rename the input image			removed for v008 so the while loop works.
		//selectWindow("OrigImage");
		//rename(OrigName);
		
		//show the composite images
		selectWindow("Composite");			// put it in middle slice and make it bright.
		Stack.setChannel(1); run("Cyan");
		Stack.setSlice(nSlices/4);	
		Stack.setChannel(2); run("Magenta");
		selectWindow("YZ rotated view");
		
		run("Channels Tool...");
	
		time5 = getTime();
		print("Generated overlay and orthoview in "+(time4-time3)/1000+" seconds");
		run("Collect Garbage");  // try and clear the RAM
		IJ.freeMemory();
		
		waitForUser("                                 Check the surface in the composite and YZ rotated Windows. \n \nAfter you press 'OK' you have the option to continue or repeat the surface detection with different parameters \n \n     Don't worry if the surface is too high or low, you can move it up or down and make it thicker in the next step...");
		selectWindow("Composite");
		rename("Surface overlay View");
	
	// Happy to proceed to setting the peeling top and bottom, or repeat the thresholding?
	
		Dialog.create("Repeat or Proceed?");
		Dialog.addMessage("If you want to adjust the thresholding for the surface layer tick the box.");
		Dialog.addCheckbox("Repeat the surface identification?", false);
		Dialog.addMessage("Otherwise, press 'OK' to proceed & fine tune the peeling's placement (up or down) & thickness...");
		
		Dialog.show();
		Repeat = Dialog.getCheckbox(); //if true repeat the threshold, if false go to the peeling thickness step

		//setBatchMode(false); //v007 clear the batch mode images.
	
		if(Repeat == true){
			selectWindow("YZ rotated view");
			close();
			selectWindow("UpperSurfacePeelings");
			close();
			selectWindow("CumulativeMaxP");
			close();
			selectWindow("Surface overlay View");
			close();
		}
	}  // end of while loop - Repeat filter threshold and surface

// v204 close some windows
	selectWindow("Surface overlay View");
	close();
	selectWindow("YZ rotated view");
	close();

// ****************************************************	
// Set the peeling top and bottom relative to surface
// ****************************************************

// 1) Upper surface = minimum filter (clij2 3d minimum in a sphere)
// 2) lower surface = maximum filter on the upper surfcec peelings
// 3) Do an AND combination of the two images.

BadPeelings = true;

while(BadPeelings){

	run("Collect Garbage");  // try and clear the RAM

		// v010 ask user for values
		//	Upper=-2;  // 4 for Veh1_21Som test image with Huang and gaus2
		//	Lower=2; // 6 for test image above

	Dialog.create("Select Peeling placement & thickness");
	Dialog.setInsets(0, 50, 0);
	Dialog.addMessage("Please enter the displacement (in pixels) \n     for the top & bottom of the peeling \n   relative to the identified surface layer");
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("This will set the top and bottom limits & the thickness of the peel");
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("The values can be: \n  - ve to move up away from the surface or\n  + ve to move down below the surface");
	Dialog.setInsets(20, 50, 0);
	Dialog.addNumber("Upper", "0", 0, 2, "pixels");
	Dialog.setInsets(0, 50, 0);
	Dialog.addNumber("Lower", "4", 0, 2, "pixels");
	
	
	Dialog.show();
	
	Upper = Dialog.getNumber(); //v011 needs to be 1 pixel up from the Cumulative MaxP as this was already eroded. v012 back to as input, dealt with below...
	Lower = Dialog.getNumber();

	print("The peelings upper & lower surfaces are displaced from the thresholded surface by "+Upper+" & "+Lower+" pixels"); //v012
	
			time6 = getTime();
			print("Adjusting the surface levels...");
	// Set the Upper surface level relative to the identified surface
	
		setBatchMode(true); //v009 hide these steps andd windows.

// find the largest displacement, run that to set the bounds
// for the smaller displacement, do either the upper or lower surface as needed.

		UpperAbs = Math.abs(Upper); // returns the value as  +ve regardless if +ve or -ve
		LowerAbs = Math.abs(Lower); // whichever of these is lower value, run that as min or max for either Upper or Lower surface

		Bounds = Math.max(UpperAbs, LowerAbs); //the larger value sets the boundary for max displacment

// if the surfaces aren't moved at all, do nothing, just keep the original peelings.

	if(Upper==0&&Lower==0){
		selectWindow("UpperSurfacePeelings");
		run("Duplicate...", "duplicate");
	}
	else{

	// set the bounds (maximum displacement)
	// Is either the upper or lower surface.
			run("CLIJ2 Macro Extensions", "cl_device=[]"); //v201
			Ext.CLIJ2_clear();
			image1="UpperSurfacePeelings";
			Ext.CLIJ2_push(image1);
			image2 = "Bounds";
			Ext.CLIJ2_maximumOctagon(image1, image2, Bounds);
			Ext.CLIJ2_pull(image2);	
	
	//move the surfaces up or down 	
	if ((UpperAbs == LowerAbs)&&(Upper < Lower)){										//v201 only use this if UpperAbs == LowerAbs and upper is -ve and lower is +ve
				selectWindow("Bounds");
			}
		else{																			// otherwise move the surfaces...
		
		// Is the upper surface displaced by the least , then run one of these:
			if ((UpperAbs < LowerAbs)||((Upper==Lower)&&(Upper>=1))) {	
				//need to subtract 1 from the value as cumulative maxp is already eroded
				Upper = Upper-1;
				
				// if upper surface is to be moved down then:
					if (Upper >0) {	
						//minimum / erode by value = Upper
						run("CLIJ2 Macro Extensions", "cl_device=[]");
						Ext.CLIJ2_clear();
						image1="CumulativeMaxP";
						Ext.CLIJ2_push(image1);
						image2 = "Bounds2";
						Ext.CLIJ2_minimumOctagon(image1, image2, Upper);
						Ext.CLIJ2_pull(image2);
					}
				
				// if upper surface is to be moved up then:
					if (Upper <0) {	
						//maximum / dilate by value = -Upper
						run("CLIJ2 Macro Extensions", "cl_device=[]");
						Ext.CLIJ2_clear();
						image1="CumulativeMaxP";
						Ext.CLIJ2_push(image1);
						image2 = "Bounds2";
						Ext.CLIJ2_maximumOctagon(image1, image2, -Upper);
						Ext.CLIJ2_pull(image2);
					}
				
				// if upper surface is unchanged then:
					if (Upper == 0) {
						selectWindow("CumulativeMaxP");
						run("Duplicate...", "title=Bounds2 duplicate");
					}
				Upper = Upper+1;					//v201 set Upper back to orig value 
			} // end of If UpperAbs>LowerAbs
		
		// Is the lower surface displaced by the least , then run one of these:
			if ((LowerAbs < UpperAbs)||((Upper==Lower)&&(Upper<1))) {														
				//need to subtract 1 from the value as cumulative maxp is already eroded
				if(Upper != Lower) Lower = Lower-1;					// don't do this if the surface is moving up (-ve) the same distance as the upper surface (i.e -5 & -5)
													
				// lower surface down
					if (Lower >0) {
						//minimum / erode by value = Lower
						run("CLIJ2 Macro Extensions", "cl_device=[]");
						Ext.CLIJ2_clear();
						// minimum
						image1="CumulativeMaxP";
						Ext.CLIJ2_push(image1);
						image2 = "Bounds2";
						Ext.CLIJ2_minimumOctagon(image1, image2, Lower);
						Ext.CLIJ2_pull(image2);
					}
				
				// if lower surface is to be moved up then:
					if (Lower <0) {	
						// maximum / dilate by value = -Lower
						run("CLIJ2 Macro Extensions", "cl_device=[]");
						Ext.CLIJ2_clear();
						image1="CumulativeMaxP";
						Ext.CLIJ2_push(image1);
						image2 = "Bounds2";
						Ext.CLIJ2_maximumOctagon(image1, image2, -Lower);
						Ext.CLIJ2_pull(image2);
					}
				
				// if lower surface unchanged
					if (Lower == 0) {
						selectWindow("CumulativeMaxP");
						run("Duplicate...", "title=Bounds2 duplicate");
					}
				if(Upper != Lower) Lower = Lower+1; // reset Lower to orig value
			} // end of if lower is the leaast displaced.
			
		// Combine the expanded / contracted CumulativeMaxP and the Bounds
		
			if ((UpperAbs > LowerAbs)||((Upper==Lower)&&(Lower<=-1))){
				imageCalculator("Subtract create stack", "Bounds","Bounds2");
			}
		
			if ((UpperAbs < LowerAbs)||((Upper==Lower)&&(Upper>=1))){
				imageCalculator("AND create stack", "Bounds","Bounds2");
			}
			
		} // end of else - only move the bounds as both surfaces moved an equal value up & down.
	} // end of else - only do the movements if needed.

	
		time7 = getTime();
		print("Surface moved in "+(time7-time6)/1000+" seconds");
		run("Collect Garbage");  // try and clear the RAM
		IJ.freeMemory();

	rename("ImagePeel");
	
	setBatchMode(false); //v009
		
	
	// make a composite to check the ImagePeel Thickness and placement
	
		run("Merge Channels...", "c1=ForThreshold c2=ImagePeel create keep"); // keep the inpt images. Need UpperSurfacePeelings to process orig image
	
		for (i = 1; i <= 2; i++) {
			selectWindow("Composite");
		    Stack.setChannel(i);
		
			run("CLIJ2 Macro Extensions", "cl_device=[]");
			Ext.CLIJ2_clear();
			// reslice left
			Ext.CLIJ2_push("Composite");
			Ext.CLIJ2_resliceLeft("Composite", resliced); //the result is upside down.
			Ext.CLIJ2_pull(resliced);
			
			rename("Resliced"+i);
		}
	
		selectWindow("Composite");
		rename("Peeling overlay");
	
	
		run("Merge Channels...", "c1=Resliced1 c2=Resliced2 create ignore");
		rename("Image Peel YZ rotated view");
		Stack.setChannel(1); run("Cyan");
		Stack.setSlice(nSlices/4);					// put it in middle slice and make it bright.
		run("Enhance Contrast", "saturated=0.35");
		Stack.setChannel(2); run("Magenta");
		run("Flip Vertically");
	
		waitForUser("Check the ImagePeel in the composite and YZ rotated Windows");

// repeat or proceed? v010

		Dialog.create("Repeat or Proceed?");
		Dialog.addMessage("If you want to adjust the peeling placement & thickness tick the box.");
		Dialog.addCheckbox("Repeat the peeling placement & thickness?", false);
		Dialog.addMessage("Otherwise, press 'OK' to proceed & apply the peeling mask to your image.");
		Dialog.show();
		BadPeelings = Dialog.getCheckbox(); //if true repeat the peeling thickness step, if false, apply the peelings

		if(BadPeelings == true){
			selectWindow("Image Peel YZ rotated view");
			close();
			selectWindow("Peeling overlay");
			close();
			selectWindow("ImagePeel");
			close();
		}

	} // end of while loop - GoodPeelings

// select the original input image and rename it back to its original name v011
	selectWindow("OrigImage");
	rename(OrigName);

// ****************************************************	
// Apply the peelings mask to the input image
// ****************************************************
// Surface Peeler - Apply peelings to image
// Takes the expanded surface peel and extracts the surfaces of a single or multichannel image.


waitForUser("Select the image you want to peel...");

setBatchMode(true); //v203

run("Collect Garbage");  // try and clear the RAM

// select the image to be peeled:	
	OrigName = getTitle();
	rename("ImageToPeel");

	Stack.getDimensions(width, height, channels, slices, frames);
	numch = channels;

	bits = bitDepth();


//	make the image peel value = 1, to mulitply again st the input image.

	selectWindow("ImagePeel");
	run("Divide...", "value=255.000 stack");
	if (bits == 16) run("16-bit");



	selectWindow("ImageToPeel");
// if it is a single channel image:
	if (numch==1){
		imageCalculator("Multiply create stack", "ImageToPeel","ImagePeel");
		rename(OrigName+"-peeled");
	}

	if (numch > 1){
		ChannelsToMerge = "";
		for (i = 1; i <=numch; i++) {	
			selectWindow("ImageToPeel");
			run("Duplicate...", "title=ch"+i+" duplicate channels="+i+"");
			imageCalculator("Multiply create stack", "ch"+i+"","ImagePeel");
			rename("Ch"+i+"-peeled");
			selectWindow("ch"+i+"");
			close();
			ChannelsToMerge = ChannelsToMerge+"c"+i+"=Ch"+i+"-peeled ";
		}
		run("Merge Channels...", ""+ChannelsToMerge+"create");
		rename(OrigName+"-peeled");
	}

// v204 close some windows
		selectWindow("ForThreshold");
		close();
		selectWindow("Peeling overlay");
		close();
		selectWindow("Image Peel YZ rotated view");
		close();


	selectWindow("ImageToPeel");
	rename(OrigName);
	selectWindow(OrigName+"-peeled");

	setBatchMode(false); //v203

	restoreSettings;
