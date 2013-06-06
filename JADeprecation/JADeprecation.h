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
 An object for checking and periodically re-checking the deprecation state of something, for example an App or API.

 How to use:
 
 1: Create a deprecation checker object with a URL to check.
 2: Set the writable properties of the checker.
 3: Set a block to be executed when the state changes using the onStateChange: method.
 4: Call beginChecking

 It is not necessary to keep a strong reference to the object because beginChecking re-schedules checks
 to happen when the cached response expires and therefore keeps the object around forever.
 Since the onStateChange: block does not take any parameters it will also usually hold a reference to the
 deprecation checker object so that it can access the state property.

 The URL should give a JSON response and the keyPathToState property should be set to give the key-path to
 a JSON string containing the deprecation state. For example the key-path to the state string in the
 following JSON would be "deprecation_info.state"

	{
		"deprecation_info" :
		{
			"state" : "deprecated"
		}
	}

 The properties stringForOkState, stringForDeprecatedState, and stringForEndOfLifeState should be set to
 the expected values from those states. When a response is received the string at the specified key-path
 is compared to these strings to determine the state. If this state has changed from its previous value
 then the block passed to onStateChange: will be executed.

 The response is cached and preserved between app-launches, so when the app is re-launched the previous
 state is still valid until it expires and no unnecessary networking requests to the URL are made.
 */
@interface JADeprecation : NSObject

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

/**
 The time to cache responses for, in seconds. Defaults to 24 hours.
 */
@property (assign, nonatomic) NSTimeInterval timeToCacheResponse;

/**
 The key-path to a string containing the deprecation state within the response.
 */
@property (strong, nonatomic) NSString* keyPathToState;

/**
 The string to expect in the response at the keyPathToState path that represents the Ok state.
 */
@property (strong, nonatomic) NSString* stringForOkState;

/**
 The string to expect in the response at the keyPathToState path that represents the Deprecated state.
 */
@property (strong, nonatomic) NSString* stringForDeprecatedState;

/**
 The string to expect in the response at the keyPathToState path that represents the End-Of-Life state.
 */
@property (strong, nonatomic) NSString* stringForEndOfLifeState;

/**
 Returns a new deprecation checker initialised with the specified URL.
 */
+ (JADeprecation*)checkerWithURL:(NSURL*)url;

/**
 Initialise with a URL.
 */
- (id)initWithURL:(NSURL*)url;

/**
 Provide a block to be executed whenever the deprecation state changes.

 This block will be dispatched on the main thread whenever the deprecation state changes.
 Since responses are cached and persisted across app-launch sessions this block may not be
 executed at all for two reasons: a) the previous (cached) state may still be valid so no
 request to the URL is needed; or b) the previous state had expired so the URL was accessed
 but the reported state is the same as before. Therefore normal operation of the app
 should not rely on this block being executed.
 */
- (void)onStateChange:(dispatch_block_t)block;

/**
 Start checking for deprecation state changes.
 
 An initial request to the URL is made to get the deprecation state and the response is cached.
 This may not result in a request to the URL if a previous request is cached and has not expired.
 Once this has been called and the checking has been scheduled, subsequent calls have no effect.
 */
- (void)beginChecking;

@end
