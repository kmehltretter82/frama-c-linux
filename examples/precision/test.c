#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "monocypher.h"
#include "monocypher-ed25519.h"
#include "utils.h"

#define SHA_512_BLOCK_SIZE 128

// Tests that hashing bit by bit yields the same hash than hashing all
// at once. (for sha512)
static int p_sha512()
{
#undef INPUT_SIZE
#define INPUT_SIZE (SHA_512_BLOCK_SIZE * 4 - 32) // total input size
    int status = 0;
    size_t i = 1;
    // outputs
    u8 hash_chunk[64];
    u8 hash_whole[64];
    // inputs
    RANDOM_INPUT(input, INPUT_SIZE);

    // Authenticate bit by bit
    crypto_sha512_ctx ctx;
    crypto_sha512_init(&ctx);
    crypto_sha512_update(&ctx, input, i);
    crypto_sha512_update(&ctx, input + i, INPUT_SIZE - i);

    Frama_C_dump_each_before();

    crypto_sha512_final(&ctx, hash_chunk);

    Frama_C_dump_each_after();

    //@ assert \initialized(((char*)hash_chunk)+(0..64 - 1));
    u8 a = hash_chunk[0];

    // status |= memcmp(hash_chunk, hash_chunk, 64);
    // printf("Hash chunk: %u \n", hash_chunk[0]);

    // // Authenticate all at once
    // crypto_sha512(hash_whole, input, INPUT_SIZE);

    // Frama_C_show_each_after(hash_chunk);

    // // Compare the results (must be the same)
    // status |= memcmp(hash_chunk, hash_whole, 64);
    // printf("%s: Sha512 (incremental)\n", status != 0 ? "FAILED" : "OK");
    return status;
}

int main(int argc, char *argv[])
{
    if (argc > 1)
    {
        sscanf(argv[1], "%" PRIu64 "", &random_state);
    }
    printf("\nRandom seed: %" PRIu64 "\n", random_state);

    int status = 0;
    printf("\nProperty based tests");
    printf("\n--------------------\n");
    status |= p_sha512();
    printf("\n%s\n\n", status != 0 ? "SOME TESTS FAILED" : "All tests OK!");
    return status;
}
