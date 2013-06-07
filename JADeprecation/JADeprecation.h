//
//  JADeprecation.h
//  JADeprecation
//
//  Created by Jay on 2013-06-05.
//  Copyright (c) 2013 Jay Abbott. All rights reserved.
//

#import <Foundation/Foundation.h>



typedef enum
{
	JADeprecationStateUnknown,
	JADeprecationStateOk,
	JADeprecationStateDeprecated,
	JADeprecationStateEndOfLife
} JADeprecationState;



/**
 An object for checking and periodically re-checking a URL to get the the deprecation state of something, for example an App or API.

 How to use:
 
 1. Create an instance with a URL to check.
 2. Set the keyPathToState, stringForOkState, stringForDeprecatedState, and stringForEndOfLifeState properties.
 3. Use onStateChange: to set a block that will be executed when the state changes.
 4. Call beginChecking to initiate checking in the background.

 The URL should give a JSON response that contains a string representing the state somewhere within it.
 The keyPathToState property is used to find this string within the JSON response.
 For example the key-path to the state-string in the following JSON would be `"deprecation_info.state"`:

	{
		"deprecation_info" :
		{
			"state" : "deprecated"
		}
	}

 The stringForOkState, stringForDeprecatedState, and stringForEndOfLifeState properties should be set to
 the possible values of the state-string within the JSON response. Like `"deprecated"` in the above example.
 The state property is derived by comparing the state-string from the JSON response to these strings.

 The response is cached in the responseDictionary property and preserved between app-launches.
 This avoids making unnecessary requests to the URL before the previous response has expired, even when the app is re-launched.
 The value stored in timeToCacheResponse at the time the request is made is used to determine when the response expires.
 When the response does expire, a new request to the URL is made and the state is updated.
 If the state has changed then the block passed to onStateChange: will be executed.

 The state is initially set to JADeprecationStateUnknown and this value is also used when
 the response has expired and when the request fails or the response can't be processed.
 For example if the response is not valid JSON or the state-string does not match any of the `stringFor***State` properties.

 It is not necessary to keep a strong reference to the object because beginChecking re-schedules checks
 to happen when the cached response expires and therefore keeps the object around forever.
 Since the block passed to onStateChange: does not take any parameters it will also usually hold a reference
 to the deprecation object so that it can access the state property.

 There are different ways to use this class, here are some examples and guidelines.
 It is expected that the URL will change over time as the component is updated.
 For example if one of the parameters in the URL is the version number of the app, this value will change
 when the app is updated and so the URL will be different. The deprecation state in the response can inform
 older versions of the app that they are deprecated while newer versions are ok.
 Old responses will still be preserved in the cache until they expire, then they are automatically removed.
 This allows multiple instances with different URLs to handle deprecation for different components,
 for example to remotely switch different features on and off.
 Creating more than one instance with the same URL will cause undefined behaviour.
 */
@interface JADeprecation : NSObject

/// @name Getting current state

/**
 The current state according to the currently cached response and the comparison properties.
 */
@property (assign, nonatomic, readonly) JADeprecationState state;

/**
 The currently cached response dictionary.
 
 This can be used to access other parameters that come back in the response.
 For example a message or an upgrade URL.
 */
@property (strong, nonatomic, readonly) NSDictionary* responseDictionary;

/// @name Configuring

/**
 The time to cache responses for, in seconds. Defaults to 24 hours.
 */
@property (assign, nonatomic) NSTimeInterval timeToCacheResponse;

/**
 The key-path to a string containing the deprecation state within the response.
 
 Set this to the key-path where the deprecation state can be found in the JSON response.
 */
@property (strong, nonatomic) NSString* keyPathToState;

/**
 The string to expect in the response at the keyPathToState path that represents the Ok state.
 
 Set this to the string that represents the JADeprecationStateOk state.
 */
@property (strong, nonatomic) NSString* stringForOkState;

/**
 The string to expect in the response at the keyPathToState path that represents the Deprecated state.

 Set this to the string that represents the JADeprecationStateDeprecated state.
 */
@property (strong, nonatomic) NSString* stringForDeprecatedState;

/**
 The string to expect in the response at the keyPathToState path that represents the End-Of-Life state.

 Set this to the string that represents the JADeprecationStateEndOfLife state.
 */
@property (strong, nonatomic) NSString* stringForEndOfLifeState;

/// @name Creating

/**
 Returns a new deprecation checker initialised with the specified URL.

 @param url	The URL to check for deprecation status.
 @return The new JADeprecation object
 */
+ (JADeprecation*)checkerWithURL:(NSURL*)url;

/**
 Initialise with a URL.

 @param url	The URL to check for deprecation status.
 @return The initialised JADeprecation object.
 */
- (id)initWithURL:(NSURL*)url;

/// @name Handling state-changes

/**
 Provide a block to be executed when the deprecation state changes.

 This block will be dispatched on the main thread when the deprecation state changes
 due to a successful response from the URL causing the state to change.
 Note that the reported state will change during configuration of the keyPathToState and
 `stringFor***State` properties, but these changes won't trigger execution of this block.
 Since responses are cached and persisted across app-launch sessions this block may not be
 executed at all for two reasons: a) the previous (cached) state may still be valid so no
 request to the URL is needed; or b) the previous state had expired so the URL was accessed
 but the reported state is the same as before. Therefore normal operation of the app
 should not rely on this block being executed.
 Instead, access the state property outside of this block and if desired execute the block manually.
 
 @param block	The block to be executed when the deprecation state changes.
 */
- (void)onStateChange:(dispatch_block_t)block;

/**
 Provide a block to be executed whenever the deprecation state is updated by accessing the URL.

 This block will be dispatched on the main thread whenever a response is successfully retrieved
 from the URL and the responseDictionary is updated.

 @param block	The block to be executed when the response is updated.
 */
- (void)onResponseUpdate:(dispatch_block_t)block;

/// @name Initiate checking

/**
 Start checking for deprecation state changes.
 
 An initial request to the URL is made to get the deprecation state and the response is cached.
 This may not result in a request to the URL if a previous response is cached and has not expired.
 Once this has been called and the checking has been scheduled, subsequent calls have no effect.
 */
- (void)beginChecking;

@end
