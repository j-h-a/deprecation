JADeprecation
=============

A small module to assist with remote deprecation of Apps, APIs, and anything else on iOS devices.

Requirements
------------

Requires iOS (5.0 and later), compiles using ARC.

Quick setup
-----------

 1. Add the repository as a sub-module in your project repository.

        git submodule add <repository-url> JADeprecation
Replace `<repository-url>` with the URL to this repository (or a fork of it) using your preferred protocol.

 2. Add `JADeprecation` as a sub-project of your Xcode project.
  - Open your project in Xcode and in the Project Navigator right-click on your project or a group where you want to add `JADeprecation` as a sub-project.
  - Select the `Add Files To "ProjectName"...` option.
  - Navigate into the `JADeprecation` directory (where the sub-module was added) and select the `JADeprecation.xcodeproj` Xcode project.
  - Choose what targets to add it to and press the Add button.

 3. Specify `JADeprecation` as a dependency of your project and link to its library.
  - Click on your project in the Project Navigator and in the main window (with the project settings) click on the target you want to configure and go to the "Build Phases" pane.
  - Expand the "Target Dependencies" section and click the `+` icon at the bottom to add a new dependency. Choose the `JADeprecation` target from the `JADeprecation` sub-project.
  - Expand the "Link Binary With Libraries" section and click the `+` icon at the bottom to add a new library. Choose `libJADeprecation.a`.

 4. Add `JADeprecation` to your header-file search paths.
  - Click on your project which is listed above the TARGETS section. Do this within the main window with the project settings (not in the Project Navigator all the way on the left). Now go to the "Build Settings" pane.
  - In the filter text-field near the top-right type `user header` and find the setting called "User Header Search Paths".
  - Edit the value for this (at the project-level) and add `JADeprecation/JADeprecation/**` to the search-paths. If you already have other search paths separate them with a space. The first part of this path is the path to the sub-module directory, so if you used a different one in step one substitute it here.

 5. Install the documentation into Xcode.
  - If you don't have `appledoc` install it by typing `brew install appledoc` (requires [homebrew][1]).
  - Change into the `JADeprecation` sub-module directory and run `appledoc .` - this builds the docset and installs it into Xcode for you. It also generates a file called `docset-installed.txt` which you can delete.

 6. Start using it in your project.
  - Type `JADeprecation` in any source file and click it while holding down the option key to bring up the documentation.

Example usage
-------------

Here is code for a fairly simple case of deprecating an application and presenting popups
to the user with a message and upgrade button when the app becomes deprecated or enf-of-life.
In more complex cases you may want to monitor (for example) the deprecation state of an API
and validate that it is "ok" before allowing any requests to be made, or remotely turn on/off
different features of your app, or point it at a different server, etc.

```objective-c

  // Construct the URL that returns the deprecation status for this version of my app
	NSString* appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	NSString* URLString = [NSString stringWithFormat:@"http://example.com/myapp/%@/status.json", appVersion];
	NSURL* deprecationStatusURL = [NSURL URLWithString:URLString];

	// Configure the deprecation checker
	JADeprecation* checker = [JADeprecation checkerWithURL:deprecationStatusURL];
	checker.keyPathToState = @"deprecation_info.state";
	checker.stringForOkState = @"ok";
	checker.stringForDeprecatedState = @"deprecated";
	checker.stringForEndOfLifeState = @"end-of-life";

	// Set up a handler block
	dispatch_block_t doPopupBlock = ^
	{
		JADeprecationState state = checker.state;
		if((state == JADeprecationStateDeprecated) || (state == JADeprecationStateEndOfLife))
		{
			NSString* message = [checker.responseDictionary valueForKeyPath:@"deprecation_info.message"];
			NSString* urlString = [checker.responseDictionary valueForKeyPath:@"deprecation_info.url"];
			NSURL* upgradeURL = [NSURL URLWithString:urlString];
			if(state == JADeprecationStateDeprecated)
			{
				// Present the message allowing user to continue or upgrade now
				[self doDeprecatedPopupWithMessage:message upgradeURL:upgradeURL];
			}
			else
			{
				// Present message only allowing the user to upgrade
				[self doEndOfLifePopupWithMessage:message upgradeURL:upgradeURL];
				[self preventAppFromFunctioning];
			}
		}
	};

	// Check the state right now. This will be unknown on the first-run
	// and the same as last time (cached state) on subsequent runs.
	if(checker.state == JADeprecationStateDeprecated)
	{
		// If current state is deprecated, do the popup every time the URL is re-checked
		// so the user sees the popup at most once every 24 hours (timeToCacheResponse).
		[checker onResponseUpdate:doPopupBlock];
	}
	else if(checker.state == JADeprecationStateEndOfLife)
	{
		// If current state is end of life, do the popup now and prevent
		// the app from doing anything else.
		doPopupBlock();
	}
	else
	{
		// State is unknown or ok, run the popup block only when the state changes.
		[checker onStateChange:doPopupBlock];
	}
	// Start the checker
	[checker beginChecking];
```

[1]: http://mxcl.github.io/homebrew/
