//
//  OFRequestQueue.m
//  DooLittle
//
//  Created by Jérôme Lebel on 18/02/13.
//  Copyright (c) 2013 Fotonauts. All rights reserved.
//

#import "OFRequestQueue.h"
#import "ObjectiveFlickr.h"

@interface OFRequestOperation : NSObject

@property (nonatomic, assign, readwrite) OFRequestQueue *requestQueue;
@property (nonatomic, retain, readwrite) NSString *methodName;
@property (nonatomic, retain, readwrite) NSDictionary *arguments;
@property (nonatomic, retain, readwrite) id sessionInfo;
@property (nonatomic, assign, readwrite) BOOL getMethod;
@property (nonatomic, assign, readwrite) id<OFFlickrAPIRequestDelegate> delegate;
@property (nonatomic, retain, readwrite) OFFlickrAPIRequest *flickrAPIRequest;

@end

@interface OFRequestQueue () <OFFlickrAPIRequestDelegate>

@property (nonatomic, retain, readwrite) OFFlickrAPIContext *flickrAPIContext;
@property (nonatomic, retain, readwrite) NSMutableArray *availableFlickrAPIRequests;
@property (nonatomic, retain, readwrite) NSMutableArray *waitingOperations;
@property (nonatomic, retain, readwrite) NSMutableArray *runningOperations;

@end

@implementation OFRequestQueue

- (id)initWithFlickrAPIContext:(OFFlickrAPIContext *)flickrAPIContext
{
    if (self = [super init]) {
        self.flickrAPIContext = flickrAPIContext;
        self.availableFlickrAPIRequests = [NSMutableArray array];
        self.waitingOperations = [NSMutableArray array];
        self.runningOperations = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    for (OFFlickrAPIRequest *request in self.availableFlickrAPIRequests) {
        request.delegate = nil;
    }
    for (OFRequestOperation *operation in self.runningOperations) {
        operation.flickrAPIRequest.delegate = nil;
    }
    self.flickrAPIContext = nil;
    self.availableFlickrAPIRequests = nil;
    self.waitingOperations = nil;
    self.runningOperations = nil;
    [super dealloc];
}

- (OFFlickrAPIRequest *)nextAvailableFlickrAPIRequest
{
    OFFlickrAPIRequest *result;
    
    result = [self.availableFlickrAPIRequests lastObject];
    if (result) {
        [result retain];
        [self.availableFlickrAPIRequests removeLastObject];
    } else if (self.availableFlickrAPIRequests.count + self.runningOperations.count < self.parallelRequestCount){
        result = [[OFFlickrAPIRequest alloc] initWithAPIContext:self.flickrAPIContext];
        result.delegate = self;
    }
    return [result autorelease];
}

- (void)runNextOperation
{
    if (self.waitingOperations.count > 0) {
        OFFlickrAPIRequest *request;
        
        request = [self nextAvailableFlickrAPIRequest];
        if (request) {
            OFRequestOperation *operation;
            
            operation = [self.waitingOperations objectAtIndex:0];
            [self.runningOperations addObject:operation];
            operation.sessionInfo = operation;
            if (operation.getMethod) {
                [request callAPIMethodWithGET:operation.methodName arguments:operation.arguments];
            } else {
                [request callAPIMethodWithPOST:operation.methodName arguments:operation.arguments];
            }
        }
    }
}

- (void)recycleFlickrAPIRequest:(OFFlickrAPIRequest *)flickrAPIRequest withOperation:(OFRequestOperation *)operation
{
    flickrAPIRequest.sessionInfo = nil;
    if (self.availableFlickrAPIRequests.count + self.runningOperations.count < self.parallelRequestCount) {
        [self.availableFlickrAPIRequests addObject:flickrAPIRequest];
    }
    operation.flickrAPIRequest = nil;
    [self.runningOperations removeObject:operation];
    [self runNextOperation];
}

- (void)callAPIMethodGet:(BOOL)get withMethodName:(NSString *)inMethodName arguments:(NSDictionary *)inArguments sessionInfo:(id)sessionInfo delegate:(id<OFFlickrAPIRequestDelegate>)delegate
{
    OFRequestOperation *operation;
    
    operation = [[OFRequestOperation alloc] init];
    operation.getMethod = get;
    operation.methodName = inMethodName;
    operation.arguments = inArguments;
    operation.sessionInfo = sessionInfo;
    operation.requestQueue = self;
    operation.delegate = delegate;
    [self.waitingOperations addObject:operation];
    [operation release];
    [self runNextOperation];
}

- (void)callAPIMethodWithGET:(NSString *)inMethodName arguments:(NSDictionary *)inArguments sessionInfo:(id)sessionInfo delegate:(id<OFFlickrAPIRequestDelegate>)delegate
{
    [self callAPIMethodGet:YES withMethodName:inMethodName arguments:inArguments sessionInfo:sessionInfo delegate:delegate];
}

- (void)callAPIMethodWithPOST:(NSString *)inMethodName arguments:(NSDictionary *)inArguments sessionInfo:(id)sessionInfo delegate:(id<OFFlickrAPIRequestDelegate>)delegate
{
    [self callAPIMethodGet:NO withMethodName:inMethodName arguments:inArguments sessionInfo:sessionInfo delegate:delegate];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didCompleteWithResponse:(NSDictionary *)inResponseDictionary
{
    OFRequestOperation *operation = inRequest.sessionInfo;
    
    if (operation.delegate && [operation.delegate respondsToSelector:@selector(flickrAPIRequest:didCompleteWithResponse:)]) {
        inRequest.sessionInfo = operation.sessionInfo;
        [operation.delegate flickrAPIRequest:inRequest didCompleteWithResponse:inResponseDictionary];
    }
    [self recycleFlickrAPIRequest:inRequest withOperation:operation];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)inError
{
    OFRequestOperation *operation = inRequest.sessionInfo;
    
    if (operation.delegate && [operation.delegate respondsToSelector:@selector(flickrAPIRequest:didFailWithError:)]) {
        inRequest.sessionInfo = operation.sessionInfo;
        [operation.delegate flickrAPIRequest:inRequest didFailWithError:inError];
    }
    [self recycleFlickrAPIRequest:inRequest withOperation:operation];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest imageUploadSentBytes:(NSUInteger)inSentBytes totalBytes:(NSUInteger)inTotalBytes
{
    OFRequestOperation *operation = inRequest.sessionInfo;
    
    if (operation.delegate && [operation.delegate respondsToSelector:@selector(flickrAPIRequest:imageUploadSentBytes:totalBytes:)]) {
        inRequest.sessionInfo = operation.sessionInfo;
        [operation.delegate flickrAPIRequest:inRequest imageUploadSentBytes:inSentBytes totalBytes:inTotalBytes];
    }
    [self recycleFlickrAPIRequest:inRequest withOperation:operation];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthRequestToken:(NSString *)inRequestToken secret:(NSString *)inSecret
{
    OFRequestOperation *operation = inRequest.sessionInfo;
    
    if (operation.delegate && [operation.delegate respondsToSelector:@selector(flickrAPIRequest:didObtainOAuthRequestToken:secret:)]) {
        inRequest.sessionInfo = operation.sessionInfo;
        [operation.delegate flickrAPIRequest:inRequest didObtainOAuthRequestToken:inRequestToken secret:inSecret];
    }
    [self recycleFlickrAPIRequest:inRequest withOperation:operation];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthAccessToken:(NSString *)inAccessToken secret:(NSString *)inSecret userFullName:(NSString *)inFullName userName:(NSString *)inUserName userNSID:(NSString *)inNSID
{
    OFRequestOperation *operation = inRequest.sessionInfo;
    
    if (operation.delegate && [operation.delegate respondsToSelector:@selector(flickrAPIRequest:didObtainOAuthAccessToken:secret:userFullName:userName:userNSID:)]) {
        inRequest.sessionInfo = operation.sessionInfo;
        [operation.delegate flickrAPIRequest:inRequest didObtainOAuthAccessToken:inAccessToken secret:inSecret userFullName:inFullName userName:inUserName userNSID:inNSID];
    }
    [self recycleFlickrAPIRequest:inRequest withOperation:operation];
}

@end

@implementation OFRequestOperation

- (void)dealloc
{
    self.methodName = nil;
    self.arguments = nil;
    self.sessionInfo = nil;
    [super dealloc];
}

@end