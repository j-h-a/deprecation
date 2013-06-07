//
//  JADeprecation.m
//  JADeprecation
//
//  Created by Jay on 2013-06-05.
//  Copyright (c) 2013 Jay Abbott. All rights reserved.
//

#import "JADeprecation.h"



#pragma mark -
#pragma mark Private interface

@interface JADeprecation ()

@property (copy, nonatomic)		NSURL*				deprecationURL;
@property (copy, nonatomic)		NSString*			stringURL;
@property (copy, nonatomic)		dispatch_block_t	onStateChangeBlock;
@property (assign, nonatomic)	BOOL				isChecking;

@property (strong, nonatomic, readonly)	NSMutableDictionary*	globalCache; // Cache for all JADeprecation objects
@property (strong, nonatomic, readonly)	NSMutableDictionary*	localCache; // Cache for this deprecation object

@end

#define		JADeprecationKeyCache		@"JADeprecation:cache"
#define		JADeprecationKeyExpiry		@"expiry"
#define		JADeprecationKeyResponse	@"response"



@implementation JADeprecation



#pragma mark -
#pragma mark Propery accessors (public)

- (JADeprecationState)state
{
	// Get the object representing the deprecation state within the response
	id stateObj = [self.responseDictionary valueForKeyPath:self.keyPathToState];
	// Get the state as a string
	NSString* stateString = nil;
	if((stateObj != nil) && [stateObj isKindOfClass:[NSString class]])
	{
		stateString = stateObj;
	}

	// Convert the state string to the enumerated type
	JADeprecationState state = JADeprecationStateUnknown;
	if(stateString != nil)
	{
		if([stateString isEqualToString:self.stringForOkState])
		{
			state = JADeprecationStateOk;
		}
		else if([stateString isEqualToString:self.stringForDeprecatedState])
		{
			state = JADeprecationStateDeprecated;
		}
		else if([stateString isEqualToString:self.stringForEndOfLifeState])
		{
			state = JADeprecationStateEndOfLife;
		}
	}

	return state;
}

- (NSDictionary*)responseDictionary
{
	return [self.localCache objectForKey:JADeprecationKeyResponse];
}



#pragma mark -
#pragma mark Propery accessors (private)

- (NSMutableDictionary*)globalCache
{
	static NSMutableDictionary* _globalCache = nil;
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

	if(_globalCache == nil)
	{
		// Get a mutable copy of the cache
		_globalCache = [[defaults dictionaryForKey:JADeprecationKeyCache] mutableCopy];
		// Create an empty cache if it doesn't exist
		if(_globalCache == nil)
		{
			_globalCache = [NSMutableDictionary dictionary];
		}

		// Make each cache-entry mutable
		for(NSString* key in _globalCache)
		{
			NSDictionary* dict = [_globalCache objectForKey:key];
			[_globalCache setObject:[dict mutableCopy] forKey:key];
		}
	}
	return _globalCache;
}

- (NSMutableDictionary*)localCache
{
	NSMutableDictionary* lc = [self.globalCache objectForKey:self.stringURL];
	if(lc == nil)
	{
		lc = [NSMutableDictionary dictionary];
		[self.globalCache setObject:lc forKey:self.stringURL];
	}
	return lc;
}



#pragma mark -
#pragma mark Object lifecycle

+ (JADeprecation*)checkerWithURL:(NSURL*)url
{
	return [[self alloc] initWithURL:url];
}

- (id)initWithURL:(NSURL*)url
{
	self = [super init];
	if(self == nil)
	{
		return nil;
	}
	self.deprecationURL = url;
	self.stringURL = [url absoluteString];
	self.timeToCacheResponse = 3600 * 24;
	return self;
}



#pragma mark -
#pragma mark Public interface implementation

- (void)onStateChange:(dispatch_block_t)block
{
	self.onStateChangeBlock = block;
}

- (void)beginChecking
{
	if(!self.isChecking)
	{
		self.isChecking = YES;
		[self scheduleNextCheck];
	}
}



#pragma mark -
#pragma mark Private methods

- (void)scheduleNextCheck
{
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	NSNumber* expiryObject = [self.localCache objectForKey:JADeprecationKeyExpiry];
	NSTimeInterval expiry = [expiryObject doubleValue];
	if(expiry < now)
	{
		[self doTheCheckNow];
	}
	else
	{
		[self doTheCheckIn:expiry - now];
	}
}

- (void)doTheCheckIn:(NSTimeInterval)delay
{
	// Schedule a check to take place in 'delay' seconds
	dispatch_after(	dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
					dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void)
	{
		[self doTheCheckNow];
	});
}

- (void)doTheCheckNow
{
	NSURLRequest* request = [NSURLRequest requestWithURL:self.deprecationURL];
	[NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue new] completionHandler:^(NSURLResponse* response, NSData* data, NSError* error)
	{
		// Check for errors
		if((error != nil) || (data == nil))
		{
			// Schedule a retry
			[self doTheCheckIn:300];
		}
		else
		{
			NSError* jsonError = nil;
			id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
			if((jsonError == nil) && [jsonObject isKindOfClass:[NSDictionary class]])
			{
				// Calculate the expiry of this response
				NSTimeInterval expiry = [NSDate timeIntervalSinceReferenceDate] + self.timeToCacheResponse;
				// Store the previous state
				JADeprecationState previousState = self.state;
				// Set the new response - which changes the state
				[self.localCache setObject:@(expiry) forKey:JADeprecationKeyExpiry];
				[self.localCache setObject:jsonObject forKey:JADeprecationKeyResponse];
				// If the state has changed, call the onStateChange block
				if((self.state != previousState) && (self.onStateChangeBlock != nil))
				{
					dispatch_async(dispatch_get_main_queue(), self.onStateChangeBlock);
				}
				// Schedule another check when the response expires
				[self doTheCheckIn:self.timeToCacheResponse];
				// Prune expired entries and save the data
				[self pruneExpiredEntries];
				[self saveCache];
			}
			else
			{
				// Schedule a retry check
				[self doTheCheckIn:3600];
			}
		}
	}];
}

- (void)pruneExpiredEntries
{
	NSTimeInterval	now = [NSDate timeIntervalSinceReferenceDate];

	// Check each entry in the global cache
	for(NSString* key in self.globalCache)
	{
		NSMutableDictionary* singleCache = [self.globalCache objectForKey:key];
		// Get the expiry time for this entry
		NSNumber* expiryObject = [singleCache objectForKey:JADeprecationKeyExpiry];
		NSTimeInterval expiry = [expiryObject doubleValue];
		// Remove the entry if it has expired
		if(expiry < now)
		{
			[self.globalCache removeObjectForKey:key];
		}
	}
}

- (void)saveCache
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:self.globalCache forKey:JADeprecationKeyCache];
	[defaults synchronize];
}

@end
