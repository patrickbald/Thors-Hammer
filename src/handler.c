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
        return handle_error(r, HTTP_STATUS_BAD_REQUEST);
    }

    /* Determine request path */
    r->path = determine_request_path(r->uri);

    if(!r->path) return handle_error(r, HTTP_STATUS_NOT_FOUND);

    debug("HTTP REQUEST PATH: %s", r->path);

    /* Dispatch to appropriate request handler type based on file type */

    struct stat request_stat;

    if(stat(r->path, &request_stat) < 0){
        return handle_error(r, HTTP_STATUS_NOT_FOUND);
    }

    if(S_ISDIR(request_stat.st_mode)){
        debug("Handle directory request");
        result = handle_browse_request(r);
    } 
    else if (access(r->path, X_OK) == 0){
        debug("Handle CGI request");
        result = handle_cgi_request(r);
    }
    else if(access(r->path, R_OK) == 0){
        debug("Handle file request");
        result = handle_file_request(r);
    } 
    else
        return HTTP_STATUS_BAD_REQUEST;

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

    n = scandir(r->path, &entries, NULL, alphasort);

    if(n < 0){
        debug("Unable to open directory: %s", strerror(errno));
        return HTTP_STATUS_BAD_REQUEST;
    }

    /* Write HTTP Header with OK Status and text/html Content-Type */

    fprintf(r->stream, "HTTP/1.0 200 OK\r\n");
    fprintf(r->stream, "Content-Type: text/html\r\n");
    fprintf(r->stream, "\r\n");

    /* For each entry in directory, emit HTML list item */

    fprintf(r->stream, "<!DOCTYPE html>\n");
    fprintf(r->stream, "<html>\n");
    fprintf(r->stream, "<head>\n");
    fprintf(r->stream, "<meta charset=\"utf-8\">\n");
    fprintf(r->stream, "<link rel=\"stylesheet\" href=\"https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0/css/bootstrap.min.css\" integrity=\"sha384-Gn5384xqQ1aoWXA+058RXPxPg6fy4IWvTNh0E263XmFcJlSAwiGgFAW/dAiS6JXm\" crossorigin=\"anonymous\">\n");
    fprintf(r->stream, "</head>\n");
    fprintf(r->stream, "<body>\n");
    

    fprintf(r->stream, "<ul class=\"list-group\">");

    for(int i = 0; i < n; i++){

        if(strcmp(entries[i]->d_name, ".") == 0){
            free(entries[i]);
            continue;
        }

        if(r->uri[strlen(r->uri) - 1] == '/'){ // has / at the end of uri
            fprintf(r->stream, "<li class=\"list-group-item\">\n<a href=\"%s%s\">%s</a>\n</li>\n", r->uri, entries[i]->d_name, entries[i]->d_name);
        }
        else{ // need to put / at end of uri
            fprintf(r->stream, "<li class=\"list-group-item\">\n<a href=\"%s/%s\">%s</a>\n</li>\n", r->uri, entries[i]->d_name, entries[i]->d_name);
        }

        free(entries[i]);
    }

    fprintf(r->stream, "</ul>");
    fprintf(r->stream, "</body>");
    fprintf(r->stream, "</html>");

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
    FILE   *fs;
    char   buffer[BUFSIZ];
    char   *mimetype = NULL;
    size_t nread;

    /* Open file for reading */

    fs = fopen(r->path, "r");
    if(!fs){
        debug("Unable to open file in handle file request");
        return handle_error(r, HTTP_STATUS_NOT_FOUND);
    }

    /* Determine mimetype */

    mimetype = determine_mimetype(r->path); // changed from r->uri @ 9:17 workingo

    if(!mimetype) goto fail;

    /* Write HTTP Headers with OK status and determined Content-Type */

    fprintf(r->stream, "HTTP/1.0 200 OK\r\n"); 
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
    
    setenv("DOCUMENT_ROOT", RootPath, true ); // overwrite
    setenv("QUERY_STRING", r->query, true);
    setenv("REMOTE_ADDR", r->host, true);
    setenv("REMOTE_PORT", r->port, true);
    setenv("REQUEST_URI", r->uri, true);
    setenv("REQUEST_METHOD", r->method, true);
    setenv("SCRIPT_FILENAME", r->path, true);
    setenv("SERVER_PORT", Port, true);

    /* Export CGI environment variables from request headers */

    for(Header* tmp = r->headers; tmp; tmp = tmp->next){

        if(streq(tmp->name, "Host")){
            setenv("HTTP_HOST", tmp->data, true);
        }
        else if (streq(tmp->name, "Connection")){
            setenv("HTTP_CONNECTION", tmp->data, true);
        }
        else if (streq(tmp->name, "Accept")){
            setenv("HTTP_ACCEPT", tmp->data, true);
        }
        else if (streq(tmp->name, "Accept-Language")){
            setenv("HTTP_ACCEPT_LANGUAGE", tmp->data, true);
        }
        else if (streq(tmp->name, "Accept-Encoding")){
            setenv("HTTP_ACCEPT_ENCODING", tmp->data, true);
        }
        else if(streq(tmp->name, "User-Agent")){
            setenv("HTTP_USER_AGENT", tmp->data, true);
        }

    }



    /* POpen CGI Script */
    pfs = popen(r->path, "r");

    debug("query is: %s", r->query);

    if(!pfs){
        debug("Unable to open CGI");
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }

    /* Copy data from popen to socket */

    while(fgets(buffer, BUFSIZ, pfs)){
        fputs(buffer, r->stream);
    }


    /* Close popen, return OK */
    pclose(pfs);

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

    char* theWay = "https://i0.wp.com/tommyeturnertalks.com/wp-content/uploads/2019/12/mandalorian-episode-5-release-time-disney-plus.jpeg?fit=1300%2C651&ssl=1";

    fprintf(r->stream, "<center>\n");
    fprintf(r->stream, "<h1 class=\"display-1\">%s</h1>", status_string);
    fprintf(r->stream, "<h2 class=\"display-2\">This is not the way</h2>\n");
    fprintf(r->stream, "<img src=\"%s\">\n", theWay);
    fprintf(r->stream, "</center>");


    /* Return specified status */
    return status; // changed from status 3:39 sunday
}

/* vim: set expandtab sts=4 sw=4 ts=8 ft=c: */
