#import <QuickLookUI/QuickLookUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface TOMLPreviewProvider : QLPreviewProvider <QLPreviewingController>
@end

@implementation TOMLPreviewProvider
- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request
                   completionHandler:(void (^)(QLPreviewReply *, NSError *))handler {
    NSURL *file = request.fileURL;
    // Xcode also assigns public.toml to .cfg and .config files.
    if (![file.pathExtension.lowercaseString isEqualToString:@"toml"]) {
        handler(nil, [NSError errorWithDomain:NSCocoaErrorDomain
                                        code:NSFeatureUnsupportedError
                                    userInfo:nil]);
        return;
    }

    QLPreviewReply *reply = [[QLPreviewReply alloc] initWithDataOfContentType:UTTypePlainText
                                                                 contentSize:CGSizeMake(0, 0)
                                                           dataCreationBlock:^NSData *(QLPreviewReply *preview, NSError **error) {
        return [NSData dataWithContentsOfURL:file options:NSDataReadingMappedIfSafe error:error];
    }];
    handler(reply, nil);
}
@end
