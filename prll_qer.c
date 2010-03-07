/* 
   Copyright 2009-2010 Jure Varlec
   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   A copy of the GNU General Public License is provided in COPYING.
   If not, see <http://www.gnu.org/licenses/>.
*/

#define _SVID_SOURCE
#include <stdio.h>
#include <sys/msg.h>
#include <stdlib.h>
#include <errno.h>
#include "mkrandom.h"

int main(int argc, char ** argv) {
  if (argc < 2) {
    fprintf(stderr,
	    "%s: message queue tool for the prll() shell function.\n"
	    "Consult the prll source and documentation for usage.\n"
	    "Not meant to be used standalone.\n"
	    , argv[0]);
    return 1;
  }

  // Choosing operating mode
  enum {
    PRLL_CLIENT_MODE, PRLL_REMOVE_MODE,
    PRLL_GETONE_MODE, PRLL_CREATE_MODE,
    PRLL_TEST_MODE
  } mode;
  if (argv[1][0] == '\0')
    goto arg_err;
  if (argv[1][0] == 'r' && argv[1][1] == '\0')
    mode = PRLL_REMOVE_MODE;
  else if (argv[1][0] == 'c' && argv[1][1] == '\0')
    mode = PRLL_CLIENT_MODE;
  else if (argv[1][0] == 'o' && argv[1][1] == '\0')
    mode = PRLL_GETONE_MODE;
  else if (argv[1][0] == 'n' && argv[1][1] == '\0')
    mode = PRLL_CREATE_MODE;
  else if (argv[1][0] == 't' && argv[1][1] == '\0')
    mode = PRLL_TEST_MODE;
  else {
  arg_err:
    fprintf(stderr, "%s: Incorrect mode specification: %s\n", argv[0], argv[1]);
    return 1;
  }

  // Open the message queue and prepare the variable for the message
  key_t qkey;
  int qid;
  if (mode != PRLL_CREATE_MODE) {
    if (argc < 3) {
      fprintf(stderr, "%s: Not enough parameters.\n", argv[0]);
      return 1;
    }
    qkey = strtol(argv[2], 0, 0);
    qid = msgget(qkey, 0);
    if (qid == -1) {
      if (mode != PRLL_TEST_MODE) {
	fprintf(stderr, "%s: Couldn't open the message queue.\n", argv[0]);
	perror(argv[0]);
      }
      return 1;
    } else if (mode == PRLL_TEST_MODE)
      return 0;
  }
  struct { long msgtype; long jarg; } msg;
  const long msgtype = 'm'+'a'+'p'+'p'; // arbitrary

  // Do the work
  // CLIENT (SEND A SINGLE MESSAGE) MODE
  if (mode == PRLL_CLIENT_MODE) {
    if (argc < 4) {
      fprintf(stderr, "%s: Not enough parameters.\n", argv[0]);
      return 1;
    }
    msg.msgtype = msgtype;
    msg.jarg = strtol(argv[3], 0, 0);
    if (errno) {
      fprintf(stderr, "%s: Couldn't read the message argument.\n", argv[0]);
      perror(argv[0]);
      return 1;
    }
    if (msgsnd(qid, &msg, sizeof(long), 0)) {
      fprintf(stderr, "%s: Couldn't send the message.\n", argv[0]);
      perror(argv[0]);
      return 1;
    }
  // GET A SINGLE MESSAGE MODE
  } else if (mode == PRLL_GETONE_MODE) {
    if (msgrcv(qid, &msg, sizeof(long), msgtype, 0) != sizeof(long)) {
      perror(argv[0]);
    }
    if (msg.jarg == 0) {
      return 0;
    } else if (msg.jarg == 1) {
      return 1;
    } else {
      fprintf(stderr, "%s: Unknown command.\n", argv[0]);
      return 1;
    }
  // CREATE A NEW QUEUE MODE
  } else if (mode == PRLL_CREATE_MODE) {
    do {
      if (mkrandom(&qkey)) {
	fprintf(stderr, "%s: Error accessing /dev/(u)random.\n", argv[0]);
	return 1;
      }
    } while (-1 == (qid = msgget(qkey, 0644 | IPC_CREAT | IPC_EXCL))
	     && errno == EEXIST);
    if (qid == -1) {
      fprintf(stderr, "%s: Couldn't create message queue.\n", argv[0]);
      perror(argv[0]);
      return 1;
    }
    printf("%#X\n", qkey);
  // REMOVE MODE
  } else if (mode == PRLL_REMOVE_MODE) {
    if (msgctl(qid, IPC_RMID, NULL)) {
      fprintf(stderr, "%s: Couldn't remove message queue.\n", argv[0]);
      perror(argv[0]);
      return 1;
    }
  }    
  return 0;
}
