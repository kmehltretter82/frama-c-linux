
static char data_rights_legend [ ] = 
  "This software (or technical data) was produced for the U. S. \
   Government under contract 2009-0917826-016 and is subject to \
   the Rights in Data-General Clause 52.227-14. Alt. IV (DEC 2007). \
\
   (c) Copyright 2012 The MITRE Corporation. All Rights Reserved.";




/********************************************************************
 ** This software (or technical data) was produced for the U. S.
 ** Government under contract 2009-0917826-016 and is subject to 
 ** the Rights in Data-General Clause 52.227-14. Alt. IV (DEC 2007).
 ** 
 ** (c) Copyright 2012 The MITRE Corporation. All Rights Reserved.
 ********************************************************************/

/*******************************************
**
**
** 
** Date: 9/16/11
**
**  Base Test Program -- SolitareEncryptionAlgorithm.c
**
** The program does this:
** 1) Reads in up to 25 bytes from a key file, and converts those characters into a 32-bit unsigned integer
** 2) Using that 32-bit unsigned integer as a seed, creates a shuffled deck of 54 cards (with jokers)
** 3) Read in a message to be encoded
** 4) Strip the message of all non-alphabet-letters
** 5) Read a new keystream value from the deck by
** 	a) Moving the first joker one spot down the deck
** 	b) Moving the second joker two spots down the deck
** 	c) Cutting the deck into three parts, and reversing the order of them relative to each other, delimited by the jokers
** 	d) Cutting the deck by as many cards as the value of the bottom card
** 	e) The next keystream value is the nth card from the top, where n is the card at the top of the deck
** 	f) The deck stays as it ends up
** 6) Encrypt the first character by adding the keystream value to it, mod 26
** 7) Perform steps 5-6 until done
**
** Decryption works similarly.
**
** See http://en.wikipedia.org/wiki/Solitaire_(cipher)
**
** Variant Test Case Program
** The program takes in a argument to either encrypt or decrypt followed by the filename. Then it attempts to print exactly when the
** user provided it.  snprintf(buf,128,argv[1] is called allowing for large format strings to be supplied that can manipulate/read
** data.
**
** STONESOUP Weakness Class: <weakness class>
** CWE ID: CWE-7134
** Variant Spreadsheet Rev #: Web site
** Variant Spreadsheet ID: 1044
**
** Variant Features:
**		SOURCE_TAINT:CERTIFICATE_CONTENTS
**		DATA_TYPE:ARRAY_LENGTH_VARIABLE
**		CONTROL_FLOW:START_CONDITION_CONTROLLED_LOOP
**		DATA_FLOW:ARRAY_INDEX_VARIABLE
**
** Initial Testing: (x means yes, - means no)
**   Tested in MS Windows XP 32bit        x
**   Tested in MS Windows 7  64bit        x
**   Tested in Ubuntu10_10 Linux 32bit    x
**   Tested in Ubuntu10_10 Linux 64bit    -
**
** Workflow:
**   Created:7/18/11
**   1st Vett:  on 7/18/11
**   2nd Vett: <peer> on <date>
**   3rd Vett:
**   4th Vett: Fortify Issues Fixed on <date>
**   5th Vett: Tested in Harness on <date>
**
**
** I/0 Pairs:
**   Good: 1st Set: encrypt input.txt output.txt deck.cer
**         2nd Set: encrypt input.txt message.txt deck.cer
**    Bad: 1st Set:	encrypt input.txt output.txt winBd.cer
*********************************************/


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <assert.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "keygen.h"

#include "random_lw.h"

#define KEY_LENGTH 25
#define DECK_SIZE 54
#define ALPHA_SIZE 26
#define FIRST_JOKER 53
#define SECOND_JOKER 54
#define MAX_MESSAGE_LENGTH 100

typedef int Card;

void print_deck (Card *deck) {
	int i;
	for (i = 0; i < DECK_SIZE; i++) {
		printf("%d ", deck[i]);
	}
	printf("\n");
}

int check_deck(Card *deck) {
	int i;
	int sum1 = 0;
	int sum2 = 0;
	for (i = 0; i < DECK_SIZE; i++) {
		sum1 += deck[i];
		sum2 += (i+1);
	}
	if (sum1 == sum2) {
		return 1;
	}
	return 0;
}

//In-place Fischer-Yates shuffle
void shuffle(Card *deck, unsigned int seed) {
	int cards_left = DECK_SIZE;
	int next_index;
	int cur_index;
	Card temp;
	srand1(seed);
	while (cards_left != 0) {
		next_index = DECK_SIZE - rand1() % cards_left - 1;
		cur_index = DECK_SIZE - cards_left;
		temp = deck[cur_index];
		deck[cur_index] = deck[next_index];
		deck[next_index] = temp;
		cards_left--;
	}
}

//turn the key into a 32-bit unsigned int via questionably required
unsigned int seedify (char *key) {
	int i;
	unsigned int seed = 0;
	for (i = 0; i < KEY_LENGTH; i++) {
		seed += (unsigned int)(key[i]) << (i % 32);
	}
	return seed;
}

//randomly initializes the deck
void init_deck(Card *deck, char *key) {
	int i;
	for (i = 0; i < DECK_SIZE; i++) {
		deck[i] = (Card)(i+1);
	}
	shuffle(deck, seedify(key));
}

int indexof (Card *deck, Card c) {
	int i;
	for (i = 0; i < DECK_SIZE; i++) {
		if (deck[i] == c) {
			return i;
		}
	}
	return -1;
}

void joker_shift(Card *deck) {
	int fji = indexof(deck, FIRST_JOKER);
	if (fji < DECK_SIZE - 1 && fji >= 0) {
		deck[fji] = deck[fji+1];
		deck[fji+1] = FIRST_JOKER;
		fji++;
	}
	int sji = indexof(deck, SECOND_JOKER);
	if (sji < DECK_SIZE - 1 && sji >= 0) {
		deck[sji] = deck[sji+1];
		deck[sji+1] = SECOND_JOKER;
		sji++;
	}
	if (sji < DECK_SIZE - 1 && sji >= 0) {
		deck[sji] = deck[sji+1];
		deck[sji+1] = SECOND_JOKER;
		sji++;
	}
}

void triple_cut(Card *deck) {
	Card helper_deck[DECK_SIZE];
	int fji = indexof(deck, FIRST_JOKER);
	int sji = indexof(deck, SECOND_JOKER);
	if (fji > DECK_SIZE || fji < 0 || sji > DECK_SIZE || sji < 0) {
		printf("Something bad happened... jokers are not there right.\n");
		return;
	}
	int top_joker_index;
	int bottom_joker_index;
	if (fji < sji) {
		top_joker_index = fji;
		bottom_joker_index = sji;
	} else {
		top_joker_index = sji;
		bottom_joker_index = fji;
	}
	int write_index = 0;
	int read_index = bottom_joker_index + 1;
	while ((read_index < DECK_SIZE) && (write_index < DECK_SIZE)) {
		helper_deck[write_index] = deck[read_index];
		read_index++;
		write_index++;
	}
	read_index = top_joker_index;
	while ((read_index <= bottom_joker_index) && (write_index < DECK_SIZE)) {
		helper_deck[write_index] = deck[read_index];
		read_index++;
		write_index++;
	}
	read_index = 0;
	while ((read_index < top_joker_index) && (write_index < DECK_SIZE)) {
		helper_deck[write_index] = deck[read_index];
		read_index++;
		write_index++;
	}
	memcpy(deck, helper_deck, DECK_SIZE * sizeof(Card));
}

void bottom_value_cut(Card *deck) {
	Card helper_deck[DECK_SIZE];
	int bottom_value = (int)deck[DECK_SIZE - 1];
	if (bottom_value >= DECK_SIZE) {
		bottom_value = DECK_SIZE - 1;
	}
	int read_index = bottom_value;
	int write_index = 0;
	while ((read_index < DECK_SIZE) && (write_index < DECK_SIZE)) {
		helper_deck[write_index] = deck[read_index];
		read_index++;
		write_index++;
	}
	read_index = 0;
	while ((read_index < bottom_value) && (write_index < DECK_SIZE)) {
		helper_deck[write_index] = deck[read_index];
		read_index++;
		write_index++;
	}
	read_index = DECK_SIZE - 1;
	while ((read_index < DECK_SIZE) && (write_index < DECK_SIZE)) {
		helper_deck[write_index] = deck[read_index];
		read_index++;
		write_index++;
	}
	memcpy(deck, helper_deck, DECK_SIZE * sizeof(Card));
}

//Does all the algorithmy stuff described in the header
int next_keystream_value (Card *deck) {
	joker_shift(deck);
	triple_cut(deck);
	bottom_value_cut(deck);
	int return_index = deck[0];
	if (return_index >= DECK_SIZE) {
		return_index = DECK_SIZE - 1;
	}
	return deck[return_index];
}

char *encrypt(Card *deck, char *message, char *encrypted) {
	int i = 0; //message index
	int j = 0; //encrypted index
	//print_deck(deck);
	char c;
	while (message[i] != '\0') {
		c = message[i];
		if (isalpha(c)) {
			c = toupper(c) - 65;
			int keystream = next_keystream_value(deck);
			encrypted[j] = (((int)c + keystream) % ALPHA_SIZE) + 65;
		 	j++;
		}
		i++;
	}
	encrypted[j] = '\0';
	return encrypted;
}

char *decrypt(Card *deck, char *message, char *decrypted) {
	int i = 0; //message index
	int j = 0; //decrypted index
	char c;
	while (message[i] != '\0') {
		c = message[i];
		if (isalpha(c)) {
			c = toupper(c) - 65;
			int keystream = next_keystream_value(deck);
			decrypted[j] = (((int)c + (ALPHA_SIZE - (keystream % ALPHA_SIZE))) % ALPHA_SIZE) + 65;
			j++;
		}
		i++;
	}
	decrypted[j] = '\0';
	return decrypted;
}

off_t get_file_size (char *fileName) {
  struct stat fileStat;
  int result;

  if ((result = stat(fileName,&fileStat)) < 0) {
    return(-1);
  }
  else {
    return(fileStat.st_size);
  }
}

int main (int argc, char *argv[]) {	//STONESOUP:CROSSOVER_POINT


	char key[KEY_LENGTH]; //char array, not a string
	Card starting_deck[DECK_SIZE];
	Card deck[DECK_SIZE];
	char in_message[MAX_MESSAGE_LENGTH];
	char out_message[MAX_MESSAGE_LENGTH];
	char *encry_message = "hello";
	FILE *otfil = NULL;
	FILE *infil = NULL;
	int c = 3;

	char *argu[3];
	char *source = argv[getIndex(1)];	//STONESOUP:DATA_FLOW:ARRAY_INDEX_VARIABLE
	char *destination = "deck.cer"; //not used in decrytion, only required during encryption.  CANT BE NULL
	char *password = "586136";
	argu[0] = source;
	argu[1] = destination;
	argu [2] = password;

	char *result = key;
	result = (char *)(decry(c,argu));	//STONESOUP:INTERACTION_POINT	//STONESOUP:SOURCE_TAINT:CERTIFICATE_CONTENTS
	//If you need to create your own certificate for first use then run the command below
	//result = encry(c,argu);



	//print deck
	init_deck(starting_deck, key);
	//print_deck(starting_deck);
	memcpy(deck, starting_deck, sizeof(Card) * DECK_SIZE); //set the deck to the key starting position

	if((strcmp(argv[1], "encrypt"))==0){
		//printf("Encrypting\n");
		if(argc != 5){
			fprintf(stderr, "Invalid number of parameters. Given %d \nUse: \n<encrypt> <filename_in> <filename_out> <deck_certificate>\n", argc);
		}

		if ((infil = fopen(argv[2], "rb")) == NULL)
		{
			fprintf(stderr, "Unable to create input file because of error\n");
			return(1);
		}
		if ((otfil = fopen(argv[3], "wb")) == NULL)
		{
			fprintf(stderr, "Unable to create output file because of error\n");
			return(1);
		}
		memset(in_message, '\0', MAX_MESSAGE_LENGTH);
		//Get input from file until end of file
		while(fgets(in_message, 100, infil) != NULL){
			if(in_message == NULL){
				fprintf(stderr, "File read failed");
				exit(1);
			}
			fprintf(stderr, "Message is: %s\n", in_message);
			encry_message = encrypt(deck, in_message, out_message);
			fprintf(stderr, "Encrypted message is:%s\n", encry_message);

			int i =0, f = 0;
			for(i = 0; encry_message[i] != '\0'; i++){ f++;}
			fwrite(encry_message, 1, f, otfil);
		}
		fclose(otfil);
	}else if((strcmp(argv[1], "decrypt"))==0){
		if(argc != 3){
			printf("Invalid number of parameters. \nUse: <decrpyt> <filename> <deck_certificate>\n");
			exit(1);
		}
		//Validate and check input from user

		if ((infil = fopen(argv[2], "rb")) == NULL)
		{
			fprintf(stderr, "Unable to create output file because of error\n");
			return(1);
		}
		if ((otfil = fopen("result.txt", "wb")) == NULL)
		{
			fprintf(stderr, "Unable to create output file because of error\n");
			return(1);
		}

		while(fgets(in_message, 100, infil) != NULL){
			if(in_message == NULL){
				printf("File read failed");
				exit(1);
			}
			fprintf(stderr, "Message is: %s\n", in_message);
			encry_message = decrypt(deck, in_message, out_message);
			fprintf(stderr, "Decrypted message is:%s\n", encry_message);

			int i =0, f = 0;
			for(i = 0; encry_message[i] != '\0'; i++){ f++;}
			fwrite(encry_message, 1, f, otfil);
		}
		fprintf(stderr, "\n\nDecrypt completed successfully and saved to result.txt\n");
	}else{
		fprintf(stderr, "Command not found! %s", argv[1]);
	}

	sleep(1);
	printf("%ld", (long int)get_file_size(argv[3]));
	fflush(stdout);


	return 0;
}
