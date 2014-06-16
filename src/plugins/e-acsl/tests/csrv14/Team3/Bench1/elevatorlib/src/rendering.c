/*
 * gui_render.c
 *
 *  Created on: 11 mars 2011
 *      Author: rapin  CEA LIST
 */

#include <string.h>
#include "elevator.h"
#include "cabin.h"


#ifdef ELEVATOR_RENDERING

//void clean_screen()
//{
//	int i,j;
//
//	for (i = 0; i < 640 ; i++)
//	{
//		for (j = 0; j < 480 ; j++)
//		{
//			DrawPixel(i, j, BLACK);
//			//putpixel(i, j, 0);
//		}
//	}
//}

void DrawPixel(int x, int y, Uint8 R, Uint8 G, Uint8 B)
{
    Uint32 color = SDL_MapRGB(screen->format, R, G, B);

    if ( SDL_MUSTLOCK(screen) ) {
        if ( SDL_LockSurface(screen) < 0 ) {
            return;
        }
    }
    switch (screen->format->BytesPerPixel) {
        case 1: { /*On gère le mode 8bpp */
            Uint8 *bufp;

            bufp = (Uint8 *)screen->pixels + y*screen->pitch + x;
            *bufp = color;
        }
        break;

        case 2: { /* Certainement 15 ou 16 bpp */
            Uint16 *bufp;

            bufp = (Uint16 *)screen->pixels + y*screen->pitch/2 + x;
            *bufp = color;
        }
        break;

        case 3: { /* 24 bpp lent et généralement pas utilisé */
            Uint8 *bufp;

            bufp = (Uint8 *)screen->pixels + y*screen->pitch + x * 3;
            if(SDL_BYTEORDER == SDL_LIL_ENDIAN) {
                bufp[0] = color;
                bufp[1] = color >> 8;
                bufp[2] = color >> 16;
            } else {
                bufp[2] = color;
                bufp[1] = color >> 8;
                bufp[0] = color >> 16;
            }
        }
        break;

        case 4: { /* Probablement 32 bpp alors */
            Uint32 *bufp;

            bufp = (Uint32 *)screen->pixels + y*screen->pitch/4 + x;
            *bufp = color;
        }
        break;
    }
    if ( SDL_MUSTLOCK(screen) ) {
        SDL_UnlockSurface(screen);
    }

}


/*
void putpixel(int x, int y, int color)
{
	int toto;

	if (x < 0 || x > 639 || y < 0 || y > 479)
		toto = 0;

  unsigned int *ptr = (unsigned int*)screen->pixels;
  int lineoffset = y * (screen->pitch / 4);
  ptr[lineoffset + x] = color;
}
*/

void elevator_rendering(int date)
{
	int i, j, bound, start;
	char date_str[16];
	SDL_Surface * texte;
	SDL_Rect position;
	SDL_Color couleur = {255, 255, 255};

	position.x = COUNTER_X_POS;
	position.y = COUNTER_Y_POS;



	// Lock surface if needed
	if (SDL_MUSTLOCK(screen))
		if (SDL_LockSurface(screen) < 0)
			return;

	bound = (622 * date) / sim_duration;

	// effacement des chiffres précédents
	for(i = 0 ; i < 40 ; i++)
	{
		for(j = 0 ; j < 20 ; j++)
		DrawPixel(COUNTER_X_POS+i, COUNTER_Y_POS+2+j, 0, 0, 0);

	}


	sprintf(date_str,"%d",date);

	// affichage des chiffres du step
    texte = TTF_RenderText_Blended(police, date_str, couleur);
    SDL_BlitSurface(texte, NULL, screen, &position); /* Blit du texte par-dessus */

    start = bound - 4;
    if (start < 20)
    	start = 20;

    // affichage de la barre de défilement
	for(i = start ; i < bound ; i++)
	{
		DrawPixel(i, 20, 0, 191, 255);
		DrawPixel(i, 21, 0, 191, 255);
		DrawPixel(i, 22, 0, 191, 255);
	}

	// rendu des cabines
	for(i = 0 ; i < NB_CABINS ; i++)
		cabin_rendering(cabins[i]);


	// Unlock if needed
	if (SDL_MUSTLOCK(screen))
		SDL_UnlockSurface(screen);

	// Tell SDL to update the whole screen
	SDL_UpdateRect(screen, 0, 0, 640, 480);

}

void elevator_rendering_init(unsigned sd)
{

	int i,j, k;
	char date_str[16];
	SDL_Surface * texte;
	SDL_Rect position;
	SDL_Color couleur = {255, 255, 255};

	if ( SDL_Init(SDL_INIT_VIDEO) < 0 )
	{
		fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
		exit(1);
	}

	if(TTF_Init() == -1)
	{
		fprintf(stderr, "Erreur d'initialisation de TTF_Init : %s\n", TTF_GetError());
		exit(EXIT_FAILURE);
	}

	police = TTF_OpenFont("ARIAL.ttf", 20);

	// Register SDL_Quit to be called at exit; makes sure things are
	// cleaned up when we quit.
	atexit(SDL_Quit);

	// Attempt to create a 640x480 window with 32bit pixels.
	screen = SDL_SetVideoMode(640, 480, 32, SDL_SWSURFACE);
	//screen = SDL_SetVideoMode(640, 480, 32, SDL_HWSURFACE | SDL_DOUBLEBUF);
	SDL_WM_SetCaption("Multi-Cars Elevator Simulation, Nicolas RAPIN, CEA LIST, France", NULL);

	// If we fail, return error.
	if ( screen == NULL )
	{
		fprintf(stderr, "Unable to set 640x480 video: %s\n", SDL_GetError());
		exit(1);
	}

	for(i = 20 ; i < 620 ; i++)
	{
		DrawPixel(i, 20, IVORY);
		DrawPixel(i, 21, IVORY);
		DrawPixel(i, 22, IVORY);
	}

	for(i = 20 ; i < 620 ; i++)
	{
		DrawPixel(i, 451, IVORY);
	}

	position.x = 35;
	position.y = 451-20;
    texte = TTF_RenderText_Blended(police, "0", couleur);
    SDL_BlitSurface(texte, NULL, screen, &position); /* Blit du texte par-dessus */

	for (k = 1  ; k < NB_FLOORS ; k++ )
	{
		j = 451 - (DOOR_HEIGHT * k);

		for(i = 20 ; i < 70 ; i++)
		{
			DrawPixel(i, j, IVORY);
		}

		position.x = 35 - (k > 9 ? 5 : 0);
		position.y = j-20;
		sprintf(date_str,"%d",k);
	    texte = TTF_RenderText_Blended(police, date_str, couleur);
	    SDL_BlitSurface(texte, NULL, screen, &position); /* Blit du texte par-dessus */
	}

	position.x = COUNTER_X_POS + 40;
	position.y = COUNTER_Y_POS;
	sprintf(date_str,"/ %d",sd);
    texte = TTF_RenderText_Blended(police, date_str, couleur);
    SDL_BlitSurface(texte, NULL, screen, &position); /* Blit du texte par-dessus */

	sim_duration = sd;

}

void elevator_rendering_close()
{
	SDL_Surface * texte;
	SDL_Rect position;
	SDL_Color couleur = {255, 255, 255};

	// Lock surface if needed
	if (SDL_MUSTLOCK(screen))
		if (SDL_LockSurface(screen) < 0)
			return;


	position.x = COUNTER_X_POS;
	position.y = COUNTER_Y_POS + 30;
    texte = TTF_RenderText_Blended(police, "End.", couleur);
    SDL_BlitSurface(texte, NULL, screen, &position); /* Blit du texte par-dessus */

	// Unlock if needed
	if (SDL_MUSTLOCK(screen))
		SDL_UnlockSurface(screen);

	// Tell SDL to update the whole screen
	SDL_UpdateRect(screen, 0, 0, 640, 480);

}


#endif
