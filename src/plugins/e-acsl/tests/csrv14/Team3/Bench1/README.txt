Nicolas RAPIN
CEA LIST
2014


Elevator Requirements French English.doc:
	is the specification of a multi-car elevator in natural language
	
elevator.req:
	a (partial) formalization of the specification
	
	

Folders: 
elevator_test
elevatorlib
	
	contain Eclipse CDT projects (created under "Ganymede" Eclipse release).
	They can be imported as C projects in a workbench. elevator_test uses elevatorlib.
	References are set in a relative manner so it should compile (with Mingw installed) if both are imported at the same level.
	
	elevatorlib: is the code for a multi-car elevator simulator with a SDL based rendering.
	elevator_test: animates the simulator (main.c contains a sequence of stimulations which animates the cabins).
	


