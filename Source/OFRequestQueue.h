//
//  OFRequestQueue.h
//  DooLittle
//
//  Created by Jérôme Lebel on 18/02/13.
//  Copyright (c) 2013 Fotonauts. All rights reserved.
//

#import <Foundation/Foundation.h>

@class OFFlickrAPIContext;
@protocol OFFlickrAPIRequestDelegate;

@interface OFRequestQueue : NSObject
{
    
}

@property (nonatomic, retain, readonly) OFFlickrAPIContext *flickrAPIContext;
@property (nonatomic, assign, readwrite) NSUInteger parallelRequestCount;

- (void)callAPIMethodWithGET:(NSString *)inMethodName arguments:(NSDictionary *)inArguments sessionInfo:(id)sessionInfo delegate:(id<OFFlickrAPIRequestDelegate>)delegate;
- (void)callAPIMethodWithPOST:(NSString *)inMethodName arguments:(NSDictionary *)inArguments sessionInfo:(id)sessionInfo delegate:(id<OFFlickrAPIRequestDelegate>)delegate;

@end
