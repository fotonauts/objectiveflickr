//
//  OFRequestQueue.h
//  DooLittle
//
//  Created by Jérôme Lebel on 18/02/13.
//  Copyright (c) 2013 Fotonauts. All rights reserved.
//

#import <Foundation/Foundation.h>

@class OFFlickrAPIContext;
@class OFRequestQueue;
@protocol OFFlickrAPIRequestDelegate;

@interface OFRequestOperation : NSObject
@property (nonatomic, assign, readwrite) id<OFFlickrAPIRequestDelegate> delegate;
@property (nonatomic, assign, readonly) OFRequestQueue *requestQueue;

- (void)cancel;

@end

@interface OFRequestQueue : NSObject
{
}

@property (nonatomic, retain, readonly) OFFlickrAPIContext *flickrAPIContext;
@property (nonatomic, assign, readwrite) NSUInteger parallelRequestCount;

- (id)initWithFlickrAPIContext:(OFFlickrAPIContext *)flickrAPIContext;

- (OFRequestOperation *)callAPIMethodWithGET:(NSString *)inMethodName arguments:(NSDictionary *)inArguments sessionInfo:(id)sessionInfo delegate:(id<OFFlickrAPIRequestDelegate>)delegate;
- (OFRequestOperation *)callAPIMethodWithPOST:(NSString *)inMethodName arguments:(NSDictionary *)inArguments sessionInfo:(id)sessionInfo delegate:(id<OFFlickrAPIRequestDelegate>)delegate;
- (void)cancelAllOperations;

@end
