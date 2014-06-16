/*
 * MonLib.h
 *
 *  Created on: 2014-04-19
 *      Author: y2joshi
 */

#ifndef MONLIB_H_
#define MONLIB_H_

#include <cmath>
#include <cstdlib>

#include <iostream>
#include <parallel/algorithm>
#include <vector>
#include <time.h>
#define NO_OF_PROPS 1

struct timespec diff_timespec(struct timespec start, struct timespec end)
{
    struct timespec result;

    if (end.tv_nsec < start.tv_nsec){
        result.tv_nsec = 1000000000 + end.tv_nsec - start.tv_nsec;
        result.tv_sec = end.tv_sec - 1 - start.tv_sec;
    }
    else{
        result.tv_nsec = end.tv_nsec - start.tv_nsec;
        result.tv_sec = end.tv_sec - start.tv_sec;
    }

    return result;
}

long long millisec_elapsed(struct timespec diff){
    return ((long long)diff.tv_sec * 1000) + (diff.tv_nsec / 1000000);
}

long long microsec_elapsed(struct timespec diff){
    return ((long long)diff.tv_sec * 1000000) + (diff.tv_nsec / 1000);
}

long long nanosec_elapsed(struct timespec diff){
    return ((long long)diff.tv_sec * 1000000000) + diff.tv_nsec;
}

enum platform
{
	CPU=1,
	GPU,
	OPENMP
};
template<typename T1>
class MonlibOpenMP
{
	T1 *trace_h;
	int (*mons[NO_OF_PROPS])(const T1&,int);
	long event_count;
	long mon_count;
	int *Result_States;
	int state_count[NO_OF_PROPS];
public:

	MonlibOpenMP(T1* trace_h,
		   long event_count,
		   long mon_count,
		   int *state_count,
		   int (*mons[])(const T1&,int)):
		   trace_h(trace_h), event_count(event_count),
		   mon_count(mon_count)
	{

		Result_States =(int*)malloc(sizeof(int)*event_count*NO_OF_PROPS);
		for(int i =0 ; i < NO_OF_PROPS;i++)
		{
			this->state_count[i] = state_count[i];
			this->mons[i] = mons[i];
		}
	}
	long long invoke_monitor(int platform)
	{
		struct timespec start, end, diff;

		clock_gettime(CLOCK_REALTIME,&start);

		long start_index = 0;
		int next_state1;

		long sum1 = 0;
		long sum2 = 0;
		long total_mons = 0;
		if(platform == CPU)
			std::sort(trace_h, trace_h + event_count);
		if(platform == OPENMP)
			__gnu_parallel::sort(trace_h, trace_h + event_count);

		for(long i =0 ; i < event_count; i++)
		{
			if(i != 0)
			{
				if(!is_equal(trace_h[i],trace_h[i-1]))
				{
					Result_States[start_index] = next_state1;

					if(next_state1 == state_count[0])
						sum1++;


					next_state1 = (*mons[0])(trace_h[i],0);

					start_index++;
					total_mons++;
				}
				next_state1 = (*mons[0])(trace_h[i], next_state1);
			}
			else
			{
				next_state1 = (*mons[0])(trace_h[i],0);
			}
		}

		clock_gettime(CLOCK_REALTIME,&end);
		diff = diff_timespec(start,end);
		return millisec_elapsed(diff);

	}
	~MonlibOpenMP()
	{
		free(Result_States);
	}
};



#endif /* MONLIB_H_ */
