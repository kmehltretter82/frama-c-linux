/**
 * Copyright 1993-2012 NVIDIA Corporation.  All rights reserved.
 *
 * Please refer to the NVIDIA end user license agreement (EULA) associated
 * with this source code for terms and conditions that govern your use of
 * this software. Any use, reproduction, disclosure, or distribution of
 * this software and related documentation outside the terms of the EULA
 * is strictly prohibited.
 */
#include <stdio.h>
#include <stdlib.h>
#include "MonLib.h"
#include <fstream>
#include <sstream>
#include <cstring>
#include <sstream>
#include <functional>
#include <mcstl.h>
#include <pthread.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <string.h>
//static const int WORK_SIZE = 256;
using namespace std;
/**
 * This macro checks return value of the CUDA runtime call and exits
 * the application if the call failed.
 */

/**
 * Host function that prepares data array and passes it to the CUDA kernel.
 */
struct program_trace
{
	long pid;
	int  fd;
	int  operation;
	int  sequence;

};

typedef enum
{
	READ=1,
	WRITE,
	OPEN,
	CLOSE,
	ACCEPT
} OPCODE;

int get_next_state1(const program_trace& trace_event, int curr_state = 0)
{
	switch(curr_state)
	{
		case 0: if(trace_event.operation == OPEN)
					return 1;
				 else
					return 0;

		case 1:	 if(trace_event.operation == CLOSE)
					return 0;
				 else
					return 1;
	}
	return 1;
}


bool is_equal (const program_trace& T1, const program_trace&T2 )
{
	if((T1.pid != T2.pid) || (T1.fd != T2.fd))
		return false;
	return true;
}


bool operator < (const program_trace &T1, const program_trace &T2 )
{
	if(T1.pid < T2.pid)
		return true;
	else
		if(T1.fd < T2.fd && T1.pid == T2.pid)
			return true;
		else
			if(T1.fd == T2.fd && T1.pid == T2.pid && T1.sequence < T2.sequence)
				return true;

	return false;
}


class CommandLineParse
{
	int argc;
	char **argv;
public:
	CommandLineParse(int argc, char *argv[]):argc(argc),argv(argv)
	{

	}
	char* parse_comamand_line(char *option, int exist = 1)
	{
		long i = 0;
		for(i = 1; i <argc; i++)
			if(strcmp(argv[i],option) == 0)
				if(!exist)
					return argv[i+1];
				else
					return argv[i];
		return 0;
	}

};
class LineParser
{
	char *line;
public:
	LineParser(){
		line = 0;
	}
	void setline(char *line)
	{
		this->line = line;
	}
	string get_field(int count)
	{
		 string line_str(line), word;
		 stringstream ss;
		 ss<<line;
		 for(int i = 0; i < count; i++)
		 {
			 ss>>word;

		 }
		 ss>>word;
		 return word;
	}
};

long MAX = 32768;
int TRACE_SIZE = 2, THRESHHOLD;

long event_count = 0;
long *trace_count;
int replicates;
MonlibOpenMP<program_trace> *mon;
int ON_CPU;
struct rusage selfstats;
struct rusage selfstats1, selfstats2;
void* run_mon(void *n)
{
	double cputime2;
	int replica = *((uint32_t *)n);
	getrusage(RUSAGE_SELF,&selfstats1);
	long long total_time = mon-> invoke_monitor(ON_CPU);
	getrusage(RUSAGE_SELF,&selfstats2);
	cputime2 = selfstats2.ru_utime.tv_sec - selfstats1.ru_utime.tv_sec;
	cputime2 += selfstats2.ru_stime.tv_sec - selfstats1.ru_stime.tv_sec;
	cputime2 +=  (selfstats2.ru_utime.tv_usec -  selfstats1.ru_utime.tv_usec)* 0.000001;
	cputime2 +=  (selfstats2.ru_stime.tv_usec -  selfstats1.ru_stime.tv_usec)* 0.000001;
	cout<<replica<<",\t"<<total_time<<",\t"<<(float)cputime2<<",\t"<<(ON_CPU == 1? "CPU":"OPENMP")<<",\t"<<MAX*TRACE_SIZE<<"\n";
	return NULL;
}

int main(int argc, char *argv[])
{

	char *filename;
	char line[1024];
	pthread_t other;
	CommandLineParse P(argc, argv);
	LineParser L;

	if(P.parse_comamand_line("-c"))
		ON_CPU = CPU;
	if(P.parse_comamand_line("-o"))
		ON_CPU = OPENMP;
	if(P.parse_comamand_line("-f",0))
	{
		filename = P.parse_comamand_line("-f",0);
	}
	else
	{
		cout<<"No trace file Option -f Provided\n";
		exit(-1);
	}
	if(P.parse_comamand_line("-l",0))
	{
		MAX = atol(P.parse_comamand_line("-l",0));
		THRESHHOLD = MAX*TRACE_SIZE*9/10;
	}
	else
	{
		cout<<"No trace length Option -l Provided\n";
		exit(-1);
	}

	replicates = 1;
	if(P.parse_comamand_line("-r",0))
	{
		replicates= atoi(P.parse_comamand_line("-r",0));
	}

	trace_count = (long*)malloc(sizeof(long)*MAX);
	memset(trace_count,0,sizeof(long)*MAX);
	program_trace *trace;

	ifstream trace_reader;

	long event_count = 0;
	int state_count[NO_OF_PROPS] = {0};
	int (*mons[NO_OF_PROPS])(const program_trace&,int);
	mons[0]=&get_next_state1;
	string str;
	size_t pos1, pos2;
	string fd; long pid;
	for(int i = 0 ; i < replicates; i++)
	{
		trace = (program_trace*)malloc(sizeof(program_trace)*MAX*TRACE_SIZE);
		mon = new MonlibOpenMP<program_trace>(trace,TRACE_SIZE*MAX, MAX,state_count,mons);

		trace_reader.open(filename,fstream::in);
		while(trace_reader.getline(line,sizeof(line)))
		{
			int operation  = 0;

			if(str.find("open(") != string::npos || str.find("open resumed") != string::npos)
				operation  = OPEN;
			if(str.find("accept(") != string::npos || str.find("accept resumed") != string::npos)
				operation  = OPEN;
			if(str.find("read(") != string::npos)
				operation  = READ;
			if(str.find("write( ") != string::npos)
				operation  = WRITE;
			if(str.find("close(") != string::npos)
				operation  = CLOSE;
			if(str.find("unfinished") != string::npos && operation != CLOSE)
				operation  = 0;

			if(str.find_first_of(" ") != string::npos)
			{
				short last_index = str.find_first_of("]");
				short first_index = str.find_first_of(" ");
				pid = atol(str.substr(first_index+1,last_index - first_index ).c_str());

			}
			switch(operation)
			{
			case READ:
				pos1 = str.find_first_of("(");
				pos2 = str.find_first_of(",",pos1+1);
				fd = str.substr(pos1+1,pos2-pos1-1);
				break;
			case OPEN:
				pos1 = str.find_last_of("=");
				fd = str.substr(pos1+2,str.length()-pos1-2);
				break;
			case WRITE:
				pos1 = str.find_first_of("(");
				pos2 = str.find_first_of(",",pos1+1);
				fd = str.substr(pos1+1,pos2-pos1-1);
				break;

			case CLOSE:

				pos1 = str.find_first_of("(");
				pos2 = str.find_first_of(")",pos1+1);
				if(pos2 == string::npos)
					pos2 = str.find_first_of(" ",pos1+1);
				fd = str.substr(pos1+1,pos2-pos1-1);
				break;
			default:break;
			}
			if(operation == READ ||
					operation == WRITE ||
					operation == OPEN ||
					operation == CLOSE)
			{
				int file_desc = atoi(fd.c_str());
				long trace_count_index = pid + ((file_desc + pid)*(file_desc + pid+1))/2;
				trace_count_index  = trace_count_index  % MAX;

				trace[event_count].pid = pid;
				trace[event_count].fd = file_desc;
				trace[event_count].operation = operation;
				trace[event_count].sequence = trace_count[trace_count_index]++;
				event_count++;

			}

			if(event_count >= THRESHHOLD )
			{
				pthread_create(&other, NULL, &run_mon,(void*) &i);
				pthread_join(other, NULL);
				event_count= 0;
				break;
			}
		}
		if(event_count != 0 )
		{
			pthread_create(&other, NULL, &run_mon,(void*) &i);
			pthread_join(other, NULL);
			event_count= 0;
		}
		trace_reader.close();

		free(trace);
		free(trace_count);
		delete mon;
		sleep(1);
	}

	return 0;
}
