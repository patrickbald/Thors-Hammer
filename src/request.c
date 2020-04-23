/* request.c: HTTP Request Functions */

#include "spidey.h"

#include <errno.h>
#include <string.h>

#include <unistd.h>

int parse_request_method(Request *r);
int parse_request_headers(Request *r);

/**
 * Accept request from server socket.
 *
 * @param   sfd         Server socket file descriptor.
 * @return  Newly allocated Request structure.
 *
 * This function does the following:
 *
 *  1. Allocates a request struct initialized to 0.
 *  2. Initializes the headers list in the request struct.
 *  3. Accepts a client connection from the server socket.
 *  4. Looks up the client information and stores it in the request struct.
 *  5. Opens the client socket stream for the request struct.
 *  6. Returns the request struct.
 *
 * The returned request struct must be deallocated using free_request.
 **/
Request * accept_request(int sfd) {
    Request *r;
    struct sockaddr raddr;
    socklen_t rlen;

    /* TODO Allocate request struct (zeroed) */

    rlen = sizeof(raddr);
    r = calloc(1, sizeof(Request));

    if(!r)
        return NULL;

    /* TODO Accept a client */

    int client_fd = accept(sfd, &raddr, &rlen);
    if(client_fd < 0){
        fprintf(stderr, "Unable to accept: %s\n", strerror(errno));
        return NULL;
    }
    debug("Client accepted");

    r->fd = client_fd;

    /* TODO Lookup client information */

    char host[NI_MAXHOST];
    char port[NI_MAXSERV];
    int flags = NI_NUMERICHOST | NI_NUMERICSERV;

    status = getnameinfo(&raddr, rlen, r->host, sizeof(host), r->port, sizeof(port), flags);
    if( status != 0){
            fprintf(stderr, "Unable to lookup request: %s\n", gai_strerror(status));
            return NULL;
    }
    debug("Client information lookup successful");

    /* TODO Open socket stream */

    r->stream = fdopen(r->fd, "w+");
    if(!r->stream){
        fprintf(stderr, "Unable to open socket stream: %s\n", strerror(errno));
        close(client_fd);
    }
    debug("Socket stream opened");

    log("Accepted request from %s:%s", r->host, r->port);
    return r;

fail:
    /* Deallocate request struct */

    free_request(r);

    return NULL;
}

/**
 * Deallocate request struct.
 *
 * @param   r           Request structure.
 *
 * This function does the following:
 *
 *  1. Closes the request socket stream or file descriptor.
 *  2. Frees all allocated strings in request struct.
 *  3. Frees all of the headers (including any allocated fields).
 *  4. Frees request struct.
 **/
void free_request(Request *r) {
    if (!r) {
    	return;
    }

    /* TODO Close socket or fd */

    if(fclose(r->stream) < 0){ // if FILE close it else close fd
        close(r->fd);
    }

    /* TODO Free allocated struct strings */

    if(r->method)   free(r->method);
    if(r->uri)      free(r->uri);
    if(r->path)     free(r->path);
    if(r->query)    free(r->query);

    /* TODO Free headers list */

    if(r->headers){

        Header* curr = r->headers;
        Header* next;
    
        while(curr){

            next = curr->next;
            if(curr->name) free(curr->name);
            if(curr->value) free(curr->value);

            free(curr);

            if(next)
                curr = next;
            else{
                free(next);
                break;
            }

        }

    } else 
        
        free(headers);

    /* TODO Free request */

    free(r);

}

/**
 * Parse HTTP Request.
 *
 * @param   r           Request structure.
 * @return  -1 on error and 0 on success.
 *
 * This function first parses the request method, any query, and then the
 * headers, returning 0 on success, and -1 on error.
 **/
int parse_request(Request *r) {

    if(!r){
        debug("No request to parse into");
        return -1;
    }

    /* TODO Parse HTTP Request Method */
    
    int methodStatus = parse_request_method(r);
    if(methodStatus < 0){
        debug("Unable to parse headers: %s\n", strerror(errno))
        return -1;
    }


    /* TODO Parse HTTP Requet Headers*/
    int requestStatus = parse_request_method(r);
    if(requestStatus < 0){
        debug("Unable to parse request: %s\n", strerror(errno));
        return -1;
    }

    return 0;
}

/**
 * Parse HTTP Request Method and URI.
 *
 * @param   r           Request structure.
 * @return  -1 on error and 0 on success.
 *
 * HTTP Requests come in the form
 *
 *  <METHOD> <URI>[QUERY] HTTP/<VERSION>
 *
 * Examples:
 *
 *  GET / HTTP/1.1
 *  GET /cgi.script?q=foo HTTP/1.0
 *
 * This function extracts the method, uri, and query (if it exists).
 **/
int parse_request_method(Request *r) {
    char buffer[BUFSIZ];
    char *method;
    char *uri;
    char *query;

    /* TODO Read line from socket */

    if(!fgets(buffer, BUFSIZ, r->stream)){
            debug("Unable to read line from socket");
            return -1;
    }

    /* TODO Parse method and uri */

    // GET RESOURCE HTTP/1.0
    // GET /script.cgi?q=monkeys HTTP/1.0

    method = strtok(buffer, WHITESPACE);
    // method = GET
    r->method = strdup(method);

    char* resource = strtok(NULL, WHITESPACE); // want to parse the same buffer, uri = resource
    // resource = /script.cgi?q=monkeys

    uri = strtok(resource, "?");
    // uri = /script.cgi

    if(uri)
        r->uri = strdup(uri);
    else
        return -1;

    query = strtok(NULL, WHITESPACE);
    // query = q=monkeys

    if(query)
        r->query = strdup(query);
    else
        return -1;

    debug("method is: %s, query is: %s\n", method, query);

    /* Record method, uri, and query in request struct */
    debug("HTTP METHOD: %s", r->method);
    debug("HTTP URI:    %s", r->uri);
    debug("HTTP QUERY:  %s", r->query);

    return 0;

fail:
    return -1;
}

/**
 * Parse HTTP Request Headers.
 *
 * @param   r           Request structure.
 * @return  -1 on error and 0 on success.
 *
 * HTTP Headers come in the form:
 *
 *  <NAME>: <DATA>
 *
 * Example:
 *
 *  Host: localhost:8888
 *  User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:29.0) Gecko/20100101 Firefox/29.0
 *  Accept: text/html,application/xhtml+xml
 *  Accept-Language: en-US,en;q=0.5
 *  Accept-Encoding: gzip, deflate
 *  Connection: keep-alive
 *
 * This function parses the stream from the request socket using the following
 * pseudo-code:
 *
 *  while (buffer = read_from_socket() and buffer is not empty):
 *      name, data  = buffer.split(':')
 *      header      = new Header(name, data)
 *      headers.append(header)
 **/
int parse_request_headers(Request *r) {
    Header *curr = NULL;
    char buffer[BUFSIZ];
    char *name;
    char *data;

    /* Parse headers from socket */

    while(fgets(buffer, BUFSIZ, r->stream) && strlen(buffer) > 2){

        // Allocate headers memory
        curr = calloc(1, sizeof(Header));

        chomp(buffer);

        name = strtok(buffer, ":");
        if(!name){
            free(curr);
            return -1;
        }

        value = strtok(NULL, WHITESPACE);
        if(!value){
            free(curr);
            return -1;
        }

        value = skip_whitespace(value);
        curr->name = strdup(name);
        curr->value = strdup(value);

        debug("current name: %s\n", curr->name);
        debug("current value: %s\n", curr->value);

        if(!(r->headers)) // first header
            r->headers = curr;
        else // has headers before it
            curr->next = curr;

    } 

#ifndef NDEBUG
    for (Header *header = r->headers; header; header = header->next) {
    	debug("HTTP HEADER %s = %s", header->name, header->data);
    }
#endif
    return 0;

fail:
    return -1;
}

/* vim: set expandtab sts=4 sw=4 ts=8 ft=c: */
