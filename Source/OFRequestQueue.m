//
//  OFRequestQueue.m
//  DooLittle
//
//  Created by Jérôme Lebel on 18/02/13.
//  Copyright (c) 2013 Fotonauts. All rights reserved.
//

#import "OFRequestQueue.h"
#import "ObjectiveFlickr.h"

@interface OFRequestOperation ()

@property (nonatomic, assign, readwrite) OFRequestQueue *requestQueue;
@property (nonatomic, retain, readwrite) NSString *methodName;
@property (nonatomic, retain, readwrite) NSDictionary *arguments;
@property (nonatomic, retain, readwrite) id sessionInfo;
@property (nonatomic, assign, readwrite) BOOL getMethod;
@property (nonatomic, assign, readwrite) id<OFFlickrAPIRequestDelegate> delegate;
@property (nonatomic, retain, readwrite) OFFlickrAPIRequest *flickrAPIRequest;

@end

@interface OFRequestQueue ()

@property (nonatomic, retain, readwrite) OFFlickrAPIContext *flickrAPIContext;
@property (nonatomic, retain, readwrite) NSMutableArray *availableFlickrAPIRequests;
@property (nonatomic, retain, readwrite) NSMutableArray *waitingOperations;
@property (nonatomic, retain, readwrite) NSMutableArray *runningOperations;

@end

@interface OFRequestQueue (OFFlickrAPIRequestDelegate) <OFFlickrAPIRequestDelegate>

@end

@implementation OFRequestQueue

- (id)initWithFlickrAPIContext:(OFFlickrAPIContext *)flickrAPIContext
{
    if (self = [super init]) {
        self.flickrAPIContext = flickrAPIContext;
        self.availableFlickrAPIRequests = [NSMutableArray array];
        self.waitingOperations = [NSMutableArray array];
        self.runningOperations = [NSMutableArray array];
        self.parallelRequestCount = 5;
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
        [operation.flickrAPIRequest cancel];
    }
    self.flickrAPIContext = nil;
    self.availableFlickrAPIRequests = nil;
    self.waitingOperations = nil;
    self.runningOperations = nil;
    [super dealloc];
}

- (OFFlickrAPIRequest *)nextAvailableFlickrAPIRequest
{
    OFFlickrAPIRequest *result = nil;
    
    if (self.availableFlickrAPIRequests.count > 0) {
        result = [[self.availableFlickrAPIRequests lastObject] retain];
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
            BOOL requestSent = NO;
            
            while (!requestSent) {
                OFRequestOperation *operation;
                
                operation = [self.waitingOperations objectAtIndex:0];
                operation.flickrAPIRequest = request;
                [self.runningOperations addObject:operation];
                request.sessionInfo = operation;
                if (operation.getMethod) {
                    requestSent = [request callAPIMethodWithGET:operation.methodName arguments:operation.arguments];
                } else {
                    requestSent = [request callAPIMethodWithPOST:operation.methodName arguments:operation.arguments];
                }
                [self.waitingOperations removeObjectAtIndex:0];
                if (!requestSent) {
                    if (operation.delegate && [operation.delegate respondsToSelector:@selector(flickrAPIRequest:didFailWithError:)]) {
                        request.sessionInfo = operation.sessionInfo;
                        [operation.delegate flickrAPIRequest:request didFailWithError:nil];
                    }
                }
            }
        }
    }
}

- (void)removeFromWaitingQueue:(OFRequestOperation *)operation
{
    [self.waitingOperations removeObject:operation];
}

- (void)recycleFlickrAPIRequestForOperation:(OFRequestOperation *)operation
{
    NSAssert(operation.flickrAPIRequest !=  nil, @"operation should have a flickr api request %@", operation);
    operation.flickrAPIRequest.sessionInfo = nil;
    // the current request is still into the running operation (for the retain count)
    // so we have to use <=
    if (self.availableFlickrAPIRequests.count + self.runningOperations.count <= self.parallelRequestCount) {
        [self.availableFlickrAPIRequests addObject:operation.flickrAPIRequest];
    }
    operation.flickrAPIRequest = nil;
    [self.runningOperations removeObject:operation];
    [self runNextOperation];
}

- (OFRequestOperation *)callAPIMethodGet:(BOOL)get withMethodName:(NSString *)inMethodName arguments:(NSDictionary *)inArguments sessionInfo:(id)sessionInfo delegate:(id<OFFlickrAPIRequestDelegate>)delegate
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
    return operation;
}

- (OFRequestOperation *)callAPIMethodWithGET:(NSString *)inMethodName arguments:(NSDictionary *)inArguments sessionInfo:(id)sessionInfo delegate:(id<OFFlickrAPIRequestDelegate>)delegate
{
    return [self callAPIMethodGet:YES withMethodName:inMethodName arguments:inArguments sessionInfo:sessionInfo delegate:delegate];
}

- (OFRequestOperation *)callAPIMethodWithPOST:(NSString *)inMethodName arguments:(NSDictionary *)inArguments sessionInfo:(id)sessionInfo delegate:(id<OFFlickrAPIRequestDelegate>)delegate
{
    return [self callAPIMethodGet:NO withMethodName:inMethodName arguments:inArguments sessionInfo:sessionInfo delegate:delegate];
}

- (void)cancelAllOperations
{
    for (OFRequestOperation *operation in self.waitingOperations) {
        [operation cancel];
    }
    [self.waitingOperations removeAllObjects];
    for (OFRequestOperation *operation in self.runningOperations.copy) {
        [operation cancel];
    }
}

@end

@implementation OFRequestQueue (OFFlickrAPIRequestDelegate)

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didCompleteWithResponse:(NSDictionary *)inResponseDictionary
{
    OFRequestOperation *operation = inRequest.sessionInfo;
    
    NSAssert(operation != nil, @"should have an operation");
    NSAssert([operation isKindOfClass:[OFRequestOperation class]], @"wrong type %@", operation);
    if (operation.delegate && [operation.delegate respondsToSelector:@selector(flickrAPIRequest:didCompleteWithResponse:)]) {
        inRequest.sessionInfo = operation.sessionInfo;
        [operation.delegate flickrAPIRequest:inRequest didCompleteWithResponse:inResponseDictionary];
    }
    [self recycleFlickrAPIRequestForOperation:operation];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)inError
{
    OFRequestOperation *operation = inRequest.sessionInfo;
    
    NSAssert(operation != nil, @"should have an operation");
    NSAssert([operation isKindOfClass:[OFRequestOperation class]], @"wrong type %@", operation);
    if (operation.delegate && [operation.delegate respondsToSelector:@selector(flickrAPIRequest:didFailWithError:)]) {
        inRequest.sessionInfo = operation.sessionInfo;
        [operation.delegate flickrAPIRequest:inRequest didFailWithError:inError];
    }
    [self recycleFlickrAPIRequestForOperation:operation];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest imageUploadSentBytes:(NSUInteger)inSentBytes totalBytes:(NSUInteger)inTotalBytes
{
    OFRequestOperation *operation = inRequest.sessionInfo;
    
    NSAssert(operation != nil, @"should have an operation");
    NSAssert([operation isKindOfClass:[OFRequestOperation class]], @"wrong type %@", operation);
    if (operation.delegate && [operation.delegate respondsToSelector:@selector(flickrAPIRequest:imageUploadSentBytes:totalBytes:)]) {
        inRequest.sessionInfo = operation.sessionInfo;
        [operation.delegate flickrAPIRequest:inRequest imageUploadSentBytes:inSentBytes totalBytes:inTotalBytes];
    }
    [self recycleFlickrAPIRequestForOperation:operation];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthRequestToken:(NSString *)inRequestToken secret:(NSString *)inSecret
{
    OFRequestOperation *operation = inRequest.sessionInfo;
    
    NSAssert(operation != nil, @"should have an operation");
    NSAssert([operation isKindOfClass:[OFRequestOperation class]], @"wrong type %@", operation);
    if (operation.delegate && [operation.delegate respondsToSelector:@selector(flickrAPIRequest:didObtainOAuthRequestToken:secret:)]) {
        inRequest.sessionInfo = operation.sessionInfo;
        [operation.delegate flickrAPIRequest:inRequest didObtainOAuthRequestToken:inRequestToken secret:inSecret];
    }
    [self recycleFlickrAPIRequestForOperation:operation];
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthAccessToken:(NSString *)inAccessToken secret:(NSString *)inSecret userFullName:(NSString *)inFullName userName:(NSString *)inUserName userNSID:(NSString *)inNSID
{
    OFRequestOperation *operation = inRequest.sessionInfo;
    
    NSAssert(operation != nil, @"should have an operation");
    NSAssert([operation isKindOfClass:[OFRequestOperation class]], @"wrong type %@", operation);
    if (operation.delegate && [operation.delegate respondsToSelector:@selector(flickrAPIRequest:didObtainOAuthAccessToken:secret:userFullName:userName:userNSID:)]) {
        inRequest.sessionInfo = operation.sessionInfo;
        [operation.delegate flickrAPIRequest:inRequest didObtainOAuthAccessToken:inAccessToken secret:inSecret userFullName:inFullName userName:inUserName userNSID:inNSID];
    }
    [self recycleFlickrAPIRequestForOperation:operation];
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

- (void)cancel
{
    if (self.flickrAPIRequest) {
        // is already running
        [self.flickrAPIRequest cancel];
        [self.requestQueue recycleFlickrAPIRequestForOperation:self];
    } else {
        // is in the waiting queue
        [self.requestQueue removeFromWaitingQueue:self];
    }
}

@end