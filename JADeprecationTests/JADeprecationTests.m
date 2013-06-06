//
//  JADeprecationTests.m
//  JADeprecationTests
//
//  Created by Jay on 2013-06-05.
//  Copyright (c) 2013 Jay Abbott. All rights reserved.
//

#import "JADeprecationTests.h"
#import "JADeprecation.h"



@implementation JADeprecationTests

// Secret insider knowledge of JADeprecation implementation for faking state
#define		JADeprecationKeyCache		@"JADeprecation:cache"
#define		JADeprecationKeyExpiry		@"expiry"
#define		JADeprecationKeyResponse	@"response"

- (void)setUp
{
	[super setUp];

	// Default to no previous state for all tests
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:JADeprecationKeyCache];
	[defaults synchronize];
}

- (void)tearDown
{
	// Tear-down code here.

	[super tearDown];
}



#pragma mark -
#pragma mark Helpers

- (NSURL*)URLForJSONFile:(NSString*)name
{
	NSBundle* bundle = [NSBundle bundleForClass:[self class]];
	NSString* path = [bundle pathForResource:name ofType:@"json"];
	return [NSURL fileURLWithPath:path];
}

- (JADeprecation*)checkerForJSONFile:(NSString*)jsonFile
{
	JADeprecation* checker = [JADeprecation checkerWithURL:[self URLForJSONFile:jsonFile]];
	checker.timeToCacheResponse = 3600 * 24;
	checker.keyPathToState = @"deprecation_info.state";
	checker.stringForOkState = @"ok";
	checker.stringForDeprecatedState = @"deprecated";
	checker.stringForEndOfLifeState = @"end-of-life";
	return checker;
}

- (void)fakePreviousResponse:(NSDictionary*)response forURL:(NSURL*)url withExpiry:(NSTimeInterval)expiry
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary* entry = [NSDictionary dictionaryWithObjectsAndKeys:response, JADeprecationKeyResponse, @(expiry), JADeprecationKeyExpiry, nil];
	NSDictionary* cache = [NSDictionary dictionaryWithObject:entry forKey:[url absoluteString]];
	[defaults setObject:cache forKey:JADeprecationKeyCache];
}

// Perform the runloop to allow execution of main thread operations and other thread operations
- (void)doRunLoopWithTimeout:(NSTimeInterval)timeout whileCondition:(BOOL (^)(void))conditionBlock
{
	// Allow the main runloop to execute while the whileBlock is true, but only up to timeout seconds
	NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
	while(conditionBlock())
	{
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
		// Stop if timeout is reached
		NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
		if((now - start) > timeout)
		{
			STFail(@"Test took longer than %.1f seconds and timed out", (float)timeout);
			break;
		}
	}
}

- (void)doTestForNoPreviousResponseWithJSONFile:(NSString*)jsonFile andExpectedState:(JADeprecationState)expectedState
{
	// Set up the checker
	JADeprecation*		checker = [self checkerForJSONFile:jsonFile];
	// Validate initial state
	JADeprecationState	expectedInitialState = JADeprecationStateUnknown;
	JADeprecationState	initialState = checker.state;
	STAssertEquals(initialState, expectedInitialState, @"Initial state not as expected.");

	// Set up the on-change block and begin checking
	__block BOOL blockCalled = NO;
	[checker onStateChange:^
	{
		blockCalled = YES;
	}];
	[checker beginChecking];

	// Allow the run-loop to execute to give checking time to take place
	[self doRunLoopWithTimeout:10.0 whileCondition:^BOOL
	{
		return !blockCalled;
	}];

	// Validate the results
	STAssertTrue(blockCalled, @"The on change block was never called.");
	STAssertEquals(checker.state, expectedState, @"The state did not change to the expected state.");
}



#pragma mark -
#pragma mark Tests

- (void)test_NoPreviousResponse_GoodDataOkResponse_StateChangedToOk
{
	[self doTestForNoPreviousResponseWithJSONFile:@"good_ok" andExpectedState:JADeprecationStateOk];
}

- (void)test_NoPreviousResponse_GoodDataDeprecatedResponse_StateChangedToDeprecated
{
	[self doTestForNoPreviousResponseWithJSONFile:@"good_dep" andExpectedState:JADeprecationStateDeprecated];
}

- (void)test_NoPreviousResponse_GoodDataEndOfLifeResponse_StateChangedToEndOfLife
{
	[self doTestForNoPreviousResponseWithJSONFile:@"good_eol" andExpectedState:JADeprecationStateEndOfLife];
}

@end
