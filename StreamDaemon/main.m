#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <unistd.h>

static NSString *const kStreamDir = @"/var/jb/var/mobile/Library/VCNext/Streams";
static NSString *const kLiveStreamPath = @"/var/jb/var/mobile/Library/VCNext/Streams/live.vcn";

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSLog(@"[VCNStreamDaemon] Starting Stream Daemon on port 1935...");

        [[NSFileManager defaultManager] createDirectoryAtPath:kStreamDir withIntermediateDirectories:YES attributes:nil error:nil];

        int server_fd = socket(AF_INET, SOCK_STREAM, 0);
        if (server_fd < 0) {
            NSLog(@"[VCNStreamDaemon] Socket creation failed.");
            return 1;
        }

        int opt = 1;
        setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        struct sockaddr_in address;
        memset(&address, 0, sizeof(address));
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = INADDR_ANY;
        address.sin_port = htons(1935);

        if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
            NSLog(@"[VCNStreamDaemon] Bind failed on port 1935.");
            close(server_fd);
            return 1;
        }

        if (listen(server_fd, 5) < 0) {
            NSLog(@"[VCNStreamDaemon] Listen failed.");
            close(server_fd);
            return 1;
        }

        NSLog(@"[VCNStreamDaemon] Listening for OBS stream on 0.0.0.0:1935");

        while (1) {
            struct sockaddr_in client_addr;
            socklen_t addr_len = sizeof(client_addr);
            int client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &addr_len);
            if (client_fd < 0) continue;

            NSLog(@"[VCNStreamDaemon] OBS client connected! Receiving data...");

            FILE *fp = fopen([kLiveStreamPath UTF8String], "wb");
            char buffer[8192];
            ssize_t bytes_read;

            while ((bytes_read = recv(client_fd, buffer, sizeof(buffer), 0)) > 0) {
                if (fp) {
                    fwrite(buffer, 1, bytes_read, fp);
                    fflush(fp);
                }
            }

            if (fp) fclose(fp);
            close(client_fd);
            NSLog(@"[VCNStreamDaemon] OBS client disconnected.");
        }

        close(server_fd);
    }
    return 0;
}
