
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
 ** Date: 7/29/2011
 **
 ** Base Test Program -- solitare.c
 **
 ** <base test program description, note that this description
 ** should not talk about things like source taint and any other
 ** variant categories as those details will change>
 **
 ** Variant Test Case Program
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
 **
 ** STONESOUP Weakness Class: Buffer overflows/underflows/out of bounds/accesses/memory safety errors
 ** CWE ID: CWE-170
 ** Variant Spreadsheet Rev #: 2
 ** Variant Spreadsheet ID: base
 **
 ** Variant Features:
 **		SOURCE_TAINT:STDIN
 **		DATA_TYPE:SIGNED_SHORT
 **		CONTROL_FLOW:INTERPROCEDURAL_2
 **		DATA_FLOW:ARRAY_INDEX_LINEAR_EXPRESSION
 **
 ** Initial Testing: (x means yes, - means no)
 **   Tested in MS Windows XP 32bit        x
 **   Tested in MS Windows 7  64bit        -
 **   Tested in Ubuntu10_10 Linux 32bit    -
 **   Tested in Ubuntu10_10 Linux 64bit    -
 **
 ** Workflow:
 **   Created:7/29/2011
 **   1st Vett: <programmer> on <date>
 **   2nd Vett: <peer> on <date>
 **   3rd Vett: <teamleader> on <date>
 **   4th Vett: Fortify Issues Fixed on <date>
 **   5th Vett: Tested in Harness on <date>
 **
 **
 ** I/0 Pairs:
 **   Good: 1st Set:
 **         2nd Set:
 **         3rd Set:
 **         4th Set:
 **         5th Set:
 **    Bad: 1st Set:
 *********************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "random_lw.h"

#define KEY_LENGTH 25
#define DECK_SIZE 54
#define ALPHA_SIZE 26
#define FIRST_JOKER 53
#define SECOND_JOKER 54
#define MAX_MESSAGE_LENGTH 20

typedef char Card;

void print_deck (Card *deck) {
	int i;
	for (i = 0; i < DECK_SIZE; i++) {
		printf("%d ", deck[i]);
	}
	printf("\n"); fflush(stdout);
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
		printf("Something bad happened... jokers are not there right.\n"); fflush(stdout);
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
	memcpy(deck, helper_deck, DECK_SIZE*sizeof(Card));
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
	memcpy(deck, helper_deck, DECK_SIZE*sizeof(Card));
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

char *encrypt(Card *deck, short *message, char *encrypted) {
	int i = 0; //message index
	int j = 0; //encrypted index
	char c;
	while (message[i] != 0 && i<MAX_MESSAGE_LENGTH) {
		c = message[i];
		if (isalpha(c)) {
			c = toupper(c) - 65;
			int keystream = next_keystream_value(deck);
			encrypted[j] = (((int)c + keystream) % ALPHA_SIZE) + 65;
			//printf("%d\n", keystream); fflush(stdout);
			j++;
		}
		i++;
	}
	encrypted[j] = '\0';
	return encrypted;
}

char *decrypt(Card *deck, short *message, char *decrypted) {
	int i = 0; //message index
	int j = 0; //decrypted index
	char c;
	while (message[i] != 0 && i<MAX_MESSAGE_LENGTH) {
		c = message[i];
		if (isalpha(c)) {
			c = toupper(c) - 65;
			int keystream = next_keystream_value(deck);
			decrypted[j] = (((int)c + (ALPHA_SIZE - (keystream % ALPHA_SIZE))) % ALPHA_SIZE) + 65;
			//printf("%d\n", keystream); fflush(stdout);
			j++;
		}
		i++;
	}
	decrypted[j] = '\0';
	return decrypted;
}

void cnvshrtchr(signed short* s, char* d)
{
	while((*d++ = ((char)*s++)) != 0);
}

void processInput(short* input, char* output, int mode, Card *deck, int msglen){
	if (!mode) {
		short *s = input;
		printf("Unencrypted: ");
		int i = 0;
		while (*s)
		{
			printf("%02X ", ((unsigned int)*s++) & 0xFF);	//STONESOUP:TRIGGER_POINT

			if (i > (msglen + 4))	/* Keep the printout manageable */
			{
				break;
			}

			i++;
		}
		printf("\n");
		printf("Encrypted: %s\n", encrypt(deck, input, output)); fflush(stdout);
	} else {
		short *s = input;
		printf("Encrypted: ");
		while (*s)
		{
			printf("%c", ((char)(*s++)));
		}
		printf("\n");
		printf("Decrypted: %s\n", decrypt(deck, input, output)); fflush(stdout);
	}
	/*for(i=0; 1==1; ++i){
			printf("%i - %c\n", in_message_short[i], in_message_short[i]);
			fflush(stdout);
			if(in_message_short[i]=='\0')
				break;
		}
		for(i=0; 1==1; ++i){
			printf("%i - %c\n", out_message[i], out_message[i]);
			fflush(stdout);
			if(in_message_short[i]=='\0')
				break;
		}*/
}

void printshort(char *prestr, short *s1, char *poststr)
{
	printf("%s", prestr);
	while (*s1)
	{
		char c = *s1++;
		printf("%02X", c);
//		putchar(c);
	}

	printf("%s", poststr);
}

// Do a string compare using a signed short to character
int shortcmp(signed short *s, char *d)
{
//	printf("'%s' ", d);
//	printshort("'", s, "'\n");
	while (1 == 1)
	{
		char s1 = *s;
		if (((s1 == 0) || (*d == 0)))
		{
			if (s1 == *d)
			{
				return 1;
			}
			return 0;
		}
		if (s1 != *d)
		{
			return 0;
		}
		s++;
		d++;
	}

	return (0);
}

int processStuff(short* input, char* output, int *mode, Card *deck, int msglen){
	if (shortcmp(input, "/quit")) {
		return 1;
	} else if (shortcmp(input, "/encrypt")) {
		*mode = 0;
		printf("Encryption mode\n"); fflush(stdout);
	} else if (shortcmp(input, "/decrypt")) {
		*mode = 1;
		printf("Decryption mode\n"); fflush(stdout);
	} else if (shortcmp(input, "/help")) {
		printf("/encrypt: switch to encryption mode\n"
				"/decrypt: switch to decryption mode\n"
				"/quit: quit program\n"); fflush(stdout);
	} else
		processInput(input, output, *mode, deck, msglen);

	return 0;
}

int main (int argc, char *argv[]) {
	char key[KEY_LENGTH]; //char array, not a string
	Card deck[DECK_SIZE];
	char out_message[MAX_MESSAGE_LENGTH];
	Card starting_deck[DECK_SIZE];
	signed short premsg[MAX_MESSAGE_LENGTH];
	signed short in_message_short[MAX_MESSAGE_LENGTH / 2];	//STONESOUP:DATA_TYPE:SIGNED_SHORT
	signed short pstmsg[MAX_MESSAGE_LENGTH];
	FILE *keyfile;
	int k, mode = 0; //encrypt = 0, decrypt = 1

	/* Initialize overflow area */
	memset(premsg, 'A', sizeof(premsg));
	memset(pstmsg, 'A', sizeof(premsg));
	premsg[0] = 0;
	premsg[sizeof(premsg) - 1] = 0;
	pstmsg[0] = 0;
	pstmsg[sizeof(pstmsg) - 1] = 0;

	keyfile = fopen("key", "r");
	if (!keyfile) {
		printf("Unable to open key file\n"); fflush(stdout);
		exit(1);
	}
	if (!fgets(key, KEY_LENGTH, keyfile)) {
		printf("Reading from key file failed\n"); fflush(stdout);
		fclose(keyfile);
		exit(1);
	}
	fclose(keyfile);

	init_deck(starting_deck, key);
	k = 0;
	while (1)
	{
		k++;
		if (k > 20)
		{
			return 1;	/* Should not have done this many loops, there is a problem */
		}
		memcpy(deck, starting_deck, sizeof(Card) * DECK_SIZE); //set the deck to the key starting position
		//print_deck(deck);
		if (!mode) {
			printf("Enter message to be encrypted (type '/help' for help):\n");
		} else {
			printf("Enter message to be decrypted (type '/help' for help):\n");
		}
		fflush(stdout);

		int i, xx = 2;
		int c = 0;
		short *s = in_message_short;
		for (i = 0; ((c = getchar()) > 0) && (c < 256); i++) {	//STONESOUP:INTERACTION_POINT	//STONESOUP:SOURCE_TAINT:STDIN
			if (i >= MAX_MESSAGE_LENGTH)
			{
				i--;
				break;
			}
			s[xx - 2] = c;	//STONESOUP:DATA_FLOW:ARRAY_INDEX_LINEAR_EXPRESSION
			if (c == '\n' || c == '\r' || c =='\0') {
				*s = '\0';
				break;
			}
			s++;
		}	//STONESOUP:CROSSOVER_POINT
//		printshort("'", in_message_short, "'\n");
		if (processStuff(in_message_short, out_message, &mode, deck, i))	//STONESOUP:CONTROL_FLOW:INTERPROCEDURAL_2
		{
			break;
		}
	}
	return 0;
}
