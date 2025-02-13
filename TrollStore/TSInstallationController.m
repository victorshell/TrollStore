#import "TSInstallationController.h"

#import "TSApplicationsManager.h"
#import "TSAppInfo.h"
#import <TSUtil.h>
#import <TSPresentationDelegate.h>

@implementation TSInstallationController

+ (void)handleAppInstallFromFile:(NSString*)pathToIPA forceInstall:(BOOL)force completion:(void (^)(BOOL, NSError*))completionBlock
{
	dispatch_async(dispatch_get_main_queue(), ^
	{
		[TSPresentationDelegate startActivity:@"Installing"];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
		{
			// Install IPA
			//NSString* log;
			int ret = [[TSApplicationsManager sharedInstance] installIpa:pathToIPA force:force log:nil];

			NSError* error;
			if(ret != 0)
			{
				error = [[TSApplicationsManager sharedInstance] errorForCode:ret];
			}

			NSLog(@"installed app! ret:%d, error: %@", ret, error);

			dispatch_async(dispatch_get_main_queue(), ^
			{
				[TSPresentationDelegate stopActivityWithCompletion:^
				{
					if(ret != 0)
					{
						UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Install Error %d", ret] message:[error localizedDescription] preferredStyle:UIAlertControllerStyleAlert];
						UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
						{
							if(ret == 171)
							{
								if(completionBlock) completionBlock(NO, error);
							}
						}];
						[errorAlert addAction:closeAction];

						if(ret == 171)
						{
							UIAlertAction* forceInstallAction = [UIAlertAction actionWithTitle:@"Force Installation" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
							{
								[self handleAppInstallFromFile:pathToIPA forceInstall:YES completion:completionBlock];
							}];
							[errorAlert addAction:forceInstallAction];
						}
						else
						{
							/*UIAlertAction* copyLogAction = [UIAlertAction actionWithTitle:@"Copy Log" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
							{
								UIPasteboard* pasteboard = [UIPasteboard generalPasteboard];
								pasteboard.string = log;
							}];
							[errorAlert addAction:copyLogAction];*/
						}

						[TSPresentationDelegate presentViewController:errorAlert animated:YES completion:nil];
					}

					if(ret != 171)
					{
						if(completionBlock) completionBlock((BOOL)error, error);
					}
				}];
			});
		});
	});
}

+ (void)presentInstallationAlertForFile:(NSString*)pathToIPA completion:(void (^)(BOOL, NSError*))completionBlock
{
	TSAppInfo* appInfo = [[TSAppInfo alloc] initWithIPAPath:pathToIPA];
	[appInfo loadInfoWithCompletion:^(NSError* error)
	{
		dispatch_async(dispatch_get_main_queue(), ^
		{
			if(!error)
			{
				UIAlertController* installAlert = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
				installAlert.attributedTitle = [appInfo detailedInfoTitle];
				installAlert.attributedMessage = [appInfo detailedInfoDescription];
				UIAlertAction* installAction = [UIAlertAction actionWithTitle:@"Install" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
				{
					[self handleAppInstallFromFile:pathToIPA completion:completionBlock];
				}];
				[installAlert addAction:installAction];

				UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action)
				{
					if(completionBlock) completionBlock(NO, nil);
				}];
				[installAlert addAction:cancelAction];

				[TSPresentationDelegate presentViewController:installAlert animated:YES completion:nil];
			}
			else
			{
				UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Parse Error %ld", error.code] message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
				UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
				[errorAlert addAction:closeAction];

				[TSPresentationDelegate presentViewController:errorAlert animated:YES completion:nil];
			}
		});
	}];
}

+ (void)handleAppInstallFromFile:(NSString*)pathToIPA completion:(void (^)(BOOL, NSError*))completionBlock
{
	[self handleAppInstallFromFile:pathToIPA forceInstall:NO completion:completionBlock];
}

+ (void)handleAppInstallFromRemoteURL:(NSURL*)remoteURL completion:(void (^)(BOOL, NSError*))completionBlock
{
	NSURLRequest* downloadRequest = [NSURLRequest requestWithURL:remoteURL];

	dispatch_async(dispatch_get_main_queue(), ^
	{
		NSURLSessionDownloadTask* downloadTask = [NSURLSession.sharedSession downloadTaskWithRequest:downloadRequest completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error)
		{
			dispatch_async(dispatch_get_main_queue(), ^
			{
				[TSPresentationDelegate stopActivityWithCompletion:^
				{
					if(error)
					{
						UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Error downloading app: %@", error] preferredStyle:UIAlertControllerStyleAlert];
						UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
						[errorAlert addAction:closeAction];

						[TSPresentationDelegate presentViewController:errorAlert animated:YES completion:^
						{
							if(completionBlock) completionBlock(NO, error);
						}];
					}
					else
					{
						NSString* tmpIpaPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmp.ipa"];
						[[NSFileManager defaultManager] removeItemAtPath:tmpIpaPath error:nil];
						[[NSFileManager defaultManager] moveItemAtPath:location.path toPath:tmpIpaPath error:nil];
						[self presentInstallationAlertForFile:tmpIpaPath completion:^(BOOL success, NSError* error)
						{
							[[NSFileManager defaultManager] removeItemAtPath:tmpIpaPath error:nil];
							if(completionBlock) completionBlock(success, error);
						}];
					}
				}];
			});
		}];

		[TSPresentationDelegate startActivity:@"Downloading" withCancelHandler:^
		{
			[downloadTask cancel];
		}];

		[downloadTask resume];
	});
}

//+ (void)showInstallAppAlertForFile:(NSString*)pathToIPA 

@end