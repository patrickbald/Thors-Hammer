/* handler.c: HTTP Request Handlers */

#include "spidey.h"

#include <errno.h>
#include <limits.h>
#include <string.h>

#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

/* Internal Declarations */
Status handle_browse_request(Request *request);
Status handle_file_request(Request *request);
Status handle_cgi_request(Request *request);
Status handle_error(Request *request, Status status);

/**
 * Handle HTTP Request.
 *
 * @param   r           HTTP Request structure
 * @return  Status of the HTTP request.
 *
 * This parses a request, determines the request path, determines the request
 * type, and then dispatches to the appropriate handler type.
 *
 * On error, handle_error should be used with an appropriate HTTP status code.
 **/
Status  handle_request(Request *r) {
    Status result;

    /* Parse request */

    int parseStatus = parse_request(r);

    if(parseStatus < 0){
       debug("Unable to parse request: %s", strerror(errno));
        return(handle_error(r, HTTP_STATUS_INTERNAL_SERVER_ERROR));
    }

    /* Determine request path */

    r->path = determine_request_path(r->uri);

    debug("HTTP REQUEST PATH: %s", r->path);

    /* Dispatch to appropriate request handler type based on file type */

    /*
    struct stat request_stat;

    if(stat(r->path, &request_stat) < 0){
        return(handle_error(r, HTTP_STATUS_BAD_REQUEST));
    }

    int haveAccess = access(r->path, R_OK | W_OK);

    bool isDir = S_ISDIR(request_stat.st_mode);

    bool isFile = S_ISREG(request_stat.st_mode);

    if(isFile && haveAccess)
        result = handle_file_request(r);
    else if (isDir && haveAccess)
        result = handle_browse_request(r);
    else if(isCGI && haveAccess)
        result = handle_cgi_request(r);

    */

    result = handle_file_request(r);

    log("HTTP REQUEST STATUS: %s", http_status_string(result));

    return result;
}

/**
 * Handle browse request.
 *
 * @param   r           HTTP Request structure.
 * @return  Status of the HTTP browse request.
 *
 * This lists the contents of a directory in HTML.
 *
 * If the path cannot be opened or scanned as a directory, then handle error
 * with HTTP_STATUS_NOT_FOUND.
 **/
Status  handle_browse_request(Request *r) {
    struct dirent **entries;
    int n;

    /* Open a directory for reading or scanning */

    n = scandir(r->path, &entries, 0, alphasort);

    if(n < 0){
        debug("Unable to open directory: %s", strerror(errno));
        return HTTP_STATUS_BAD_REQUEST;
    }

    /* Write HTTP Header with OK Status and text/html Content-Type */

    fprintf(r->stream, "HTTP/1.0 200 OK\r\n");
    fprintf(r->stream, "Content-Type: text/html\r\n");
    fprintf(r->stream, "\r\n");

    /* For each entry in directory, emit HTML list item */

    // need to add more logic for links etc

    for(int i = 0; i < n; i++){

        if(strcmp(entries[i]->d_name, ".") == 0 || strcmp(entries[i]->d_name, "..") == 0){
            continue;
        }

        fprintf(r->stream, "<li>%s</li>", entries[i]->d_name);
        free(entries[i]);
    }

    free(entries);

    /* Return OK */
    return HTTP_STATUS_OK;
}

/**
 * Handle file request.
 *
 * @param   r           HTTP Request structure.
 * @return  Status of the HTTP file request.
 *
 * This opens and streams the contents of the specified file to the socket.
 *
 * If the path cannot be opened for reading, then handle error with
 * HTTP_STATUS_NOT_FOUND.
 **/
Status  handle_file_request(Request *r) {
    FILE *fs;
    char buffer[BUFSIZ];
    char *mimetype = NULL;
    size_t nread;

    /* Open file for reading */

    fs = fopen(r->path, "r");
    if(!fs){
        debug("Unable to open file in handle file request");
        goto fail;
    }

    /* Determine mimetype */

    mimetype = determine_mimetype(r->uri);

    /* Write HTTP Headers with OK status and determined Content-Type */

    // test
    fprintf(r->stream, "HTTP1/0 200 OK\r\n"); 
    fprintf(r->stream, "Content-Type: %s\r\n", mimetype);
    fprintf(r->stream, "\r\n");

    /* Read from file and write to socket in chunks */

    nread = fread(buffer, 1, BUFSIZ, fs);

    while( nread > 0 ){
        
        fwrite(buffer, 1, nread, r->stream);
        nread = fread(buffer, 1, BUFSIZ, fs);

    }

    /* Close file, deallocate mimetype, return OK */

    fclose(fs);

    free(mimetype);

    return HTTP_STATUS_OK;

fail:
    /* Close file, free mimetype, return INTERNAL_SERVER_ERROR */

    if(fs) fclose(fs);

    if(mimetype) free(mimetype);

    return HTTP_STATUS_INTERNAL_SERVER_ERROR;
}

/**
 * Handle CGI request
 *
 * @param   r           HTTP Request structure.
 * @return  Status of the HTTP file request.
 *
 * This popens and streams the results of the specified executables to the
 * socket.
 *
 * If the path cannot be popened, then handle error with
 * HTTP_STATUS_INTERNAL_SERVER_ERROR.
 **/
Status  handle_cgi_request(Request *r) {
    FILE *pfs;
    char buffer[BUFSIZ];

    /* Export CGI environment variables from request:
     * http://en.wikipedia.org/wiki/Common_Gateway_Interface */

    /* Export CGI environment variables from request headers */

    /* POpen CGI Script */

    /* Copy data from popen to socket */

    /* Close popen, return OK */
    return HTTP_STATUS_OK;
}

/**
 * Handle displaying error page
 *
 * @param   r           HTTP Request structure.
 * @return  Status of the HTTP error request.
 *
 * This writes an HTTP status error code and then generates an HTML message to
 * notify the user of the error.
 **/
Status  handle_error(Request *r, Status status) {
    const char *status_string = http_status_string(status);

    /* Write HTTP Header */
    fprintf(r->stream, "HTTP/1.0 %s\r\n", status_string);
    fprintf(r->stream, "Content-Type: text/html\r\n");
    fprintf(r->stream, "\r\n");

    /* Write HTML Description of Error*/
    fprintf(r->stream, "<h1> %s </h1>", status_string);

    /* Return specified status */
    return status;
}

/* vim: set expandtab sts=4 sw=4 ts=8 ft=c: */
