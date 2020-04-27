/* forking.c: Forking HTTP Server */

#include "spidey.h"

#include <errno.h>
#include <signal.h>
#include <string.h>

#include <unistd.h>

/**
 * Fork incoming HTTP requests to handle the concurrently.
 *
 * @param   sfd         Server socket file descriptor.
 * @return  Exit status of server (EXIT_SUCCESS).
 *
 * The parent should accept a request and then fork off and let the child
 * handle the request.
 **/
int forking_server(int sfd) {
    /* Accept and handle HTTP request */
    while (true) {
    	/* Accept request */

        Request* r = accept_request(sfd);

	/* Ignore children */

        signal(SIGCHLD, SIG_IGN);

	/* Fork off child process to handle request */

        pid_t pid = fork();

        if(pid < 0){
            debug("Fork has failed %s", strerror(errno));
            free_request(r);
            continue;
        }

        if(pid == 0){ // child
            debug("handling client request");
            close(sfd);
            Status s = handle_request(r);
            exit(s);
        } else { // parent process
            // close(sfd);
            free_request(r); // TODO takes request structure as argument 
        }

    }

    /* Close server socket */
    return EXIT_SUCCESS;
}

/* vim: set expandtab sts=4 sw=4 ts=8 ft=c: */
