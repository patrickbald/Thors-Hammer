#!/usr/bin/env python3

import concurrent.futures
import os
import requests
import sys
import time

# Functions

def usage(status=0):
    progname = os.path.basename(sys.argv[0])
    print(f'''Usage: {progname} [-h HAMMERS -t THROWS] URL
    -h  HAMMERS     Number of hammers to utilize (1)
    -t  THROWS      Number of throws per hammer  (1)
    -v              Display verbose output
    ''')
    sys.exit(status)

def hammer(url, throws, verbose, hid):
    ''' Hammer specified url by making multiple throws (ie. HTTP requests).

    - url:      URL to request
    - throws:   How many times to make the request
    - verbose:  Whether or not to display the text of the response
    - hid:      Unique hammer identifier

    Return the average elapsed time of all the throws.
    '''
    
    startTime = time.time()
    totalElasped = 0
    for i in range(throws):
        response = requests.get(url)
        endTime = time.time()
        elapsedTime = round(endTime - startTime, 2)
        totalElasped += elapsedTime

        if(verbose):
            print(response.text)

        print("Hammer: {}, Throw:    {}, Elapsed Time: {}".format(hid, i, elapsedTime))
        
    # average time across requests for this process
    average = totalElasped / throws
    print("Hammer: {}, AVERAGE    , Elapsed Time: {}".format(hid, average))


    return average

def do_hammer(args):
    ''' Use args tuple to call `hammer` '''
    return hammer(*args)

def main():
    hammers = 1
    throws  = 1
    verbose = False

    # TODO Parse command line arguments

    cmdargs = sys.argv[1:]

    while cmdargs and cmdargs[0].startswith('-'):
        arg = cmdargs.pop(0)
        if arg == '-h':
            hammers = int(cmdargs.pop(0))
        elif arg == '-t':
            throws = int(cmdargs.pop(0))
        elif arg == '-v':
            verbose = True

    # remaining args should be url
    if(len(cmdargs) == 0):
        usage(1)

    URL = cmdargs.pop(0);

    # sequence of argument tuples with differing hammer ID
    args = [ (URL, throws, verbose, i) for i in range(hammers) ]

    # TODO Create pool of workers and perform throws

    totalTime = 0 
    
    with concurrent.futures.ProcessPoolExecutor(hammers) as executor:
        totalTime = sum(executor.map(do_hammer, args))
    
    # average time across all hammers 
    avgTime = totalTime / hammers; 
    print("TOTAL AVERAGE ELAPSED TIME: {}".format(avgTime))
    
    

# Main execution

if __name__ == '__main__':
    main()

# vim: set sts=4 sw=4 ts=8 expandtab ft=python:
