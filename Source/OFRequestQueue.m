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

@end

@interface OFRequestQueue () <OFFlickrAPIRequestDelegate>

@property (nonatomic, retain, readwrite) OFFlickrAPIContext *flickrAPIContext;
@property (nonatomic, retain, readwrite) NSMutableArray *allFlickrAPIRequests;
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
        [self.availableFlickrAPIRequests removeLastObject];
    } else if (self.allFlickrAPIRequests.count < self.parallelRequestCount){
        result = [[OFFlickrAPIRequest alloc] initWithAPIContext:self.flickrAPIContext];
        result.delegate = self;
        [self.allFlickrAPIRequests addObject:result];
        [result release];
    }
    return result;
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
    
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)inError
{
    
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest imageUploadSentBytes:(NSUInteger)inSentBytes totalBytes:(NSUInteger)inTotalBytes
{
    
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthRequestToken:(NSString *)inRequestToken secret:(NSString *)inSecret
{
    
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didObtainOAuthAccessToken:(NSString *)inAccessToken secret:(NSString *)inSecret userFullName:(NSString *)inFullName userName:(NSString *)inUserName userNSID:(NSString *)inNSID
{
    
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