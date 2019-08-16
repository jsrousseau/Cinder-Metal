CHANGELOG
=========

2019-08-15 JSR
--------------
- started from the impressive work [William Lindmeir](http://wdlindmeier.com/) did in 2017 with [the original Cinder-Metal block](https://github.com/wdlindmeier/Cinder-Metal)
- updated the README with links to recent documentation about Metal
- made sure all macOS samples included in Cinder-Metal still compile - I did NOT have to change anything to compile all of them
- BUT to compile the iOS samples I had to do do the following changes : 
- all iOS samples : changed deployment targets to iOS 11.0
- /samples/ARKit iOS : changed the 'Other Linker Flags' value to the new '/lib/ios/Debug/libcinder.a' format
- /samples/ARKit iOS : removed 32-bit targets
- /samples/ARKit iOS : fixed unknown type ``ARWorldTrackingSessionConfiguration`` - it's now ``ARWorldTrackingConfiguration``
- /samples/ARKit iOS : fixed unknown selector ``projectionMatrixWithViewportSize`` - it's now ``projectionMatrixForOrientation``
- /samples/ARKit iOS : had to delete a line in 'Build Phases > Copy Bundle Resources' that wanted to copy an inexistant assets folder
- /samples/MetalCamera iOS : for some reason the cinder path was not the default for a sample inside a block, changed it back to : '../../../../..'
- /samples/MetalCamera iOS : had to delete a line in 'Build Phases > Copy Bundle Resources' that wanted to copy an inexistant assets folder
- /samples/MetalCamera iOS : minor changes to the ``setup()`` and ``draw()`` methods
- /samples/VideoMetalTexture iOS : removed 32-bit targets
- /samples/VideoMetalTexture iOS : changed the 'Other Linker Flags' value to the new '/lib/ios/Debug/libcinder.a' format
- /samples/VideoMetalTexture iOS : for some reason the cinder path was not the default for a sample inside a block, changed it back to : '../../../../'
- /samples/VideoMetalTexture iOS : added an assets folder with a 10MB .mp4 file for testing (thanks Beeple)
- /samples/VideoMetalTexture iOS : some minor changes to MovieMetal.mm to fix some deprecation warnings
- /samples/VideoMetalTexture iOS : added ``volume`` to the options
- important : due to the way I originally compiled libcinder.a for iOS, I had to disable bitcode on all xcode_ios sample projects