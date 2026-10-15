//this manages the larger memory operations as well as handle macro macro operations and routing.
//in charge of translating and feeding the micro operations
//when the alu is going to be idle for long periods, it can ask for the registers to be dumped and another thread to be run
//also does program counter stuff

//this always has 4 bytes of parameters and 2 bytes of action lined up
//it does not have a branch predictor but hey we can't be perfect

//if a jump is executed it will have to dump the prefetch and stuff

//this also serves as the primary memory controller and handles bus communications too


/*
the memory arbiter is a key part of this design, balancing reads writes etc.
first priority : shadow registers because the alu cannot execute without.

it determines which bytes are the most important to read from sram
first reads 1 action and 1 param byte and does a decode to see how much params it needs, 


param pad1

if the param byte contains padding, then this means the next instruction contains 3 params, as well as a fast first instruction

thus the arbiter will read twice to get

pad2 param1

param2 param3

after reading, it will align the params properly

remember, when doing parameter math, x means padding, p means parameter
2+2 = 3 bytes p p | x p | p x
2+1 = 2 bytes p p | p z | 
1+2 = 2 bytes p x | p p |
1+3 = 3 bytes p x | x p | p p
3+1 = 2 bytes p p | p p |
1+1 = 1 byte  p p |

when executing these instructions, it also tells the alu to tick the action rom counter as well as the param counter by the precalculated amount

the local buffer can store up to 64 bytes internally

*/
