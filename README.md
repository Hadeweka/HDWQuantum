# HDWQuantum

Very basic quantum computer simulation in Ruby, can be used for arbitrary complex quantum computation simulations. Not very fast, however.

## Instructions and informations

See 'HDWQuantumTest.rb' for a simple example.
Initialize a quantum register with the 'Quantum_Register' class by using:

* qreg = Quantum_Register.new(*size*, *state*)

Here, *size* is the number of qubits in the register and *state* the initial state as a binary number. You can apply quantum operations using:

* qreg.apply_one_qubit_gate(*gate*, *bit*)
* qreq.apply_two_qubit_gate(*gate*, *first bit*, *second bit*)
* ...

The *gate* can be any fitting gate (see 'HDWQuantum.rb' for a list), and the bits are the qubit positions (highest binary bit is defined as 1). A measurement can be done with:

* qreq.measure

And you can cheat by yielding the state vector by:

* qreg.output_state_vector

However, this would not be possible on a real quantum computer and is only helpful for debugging or obtaining a probability table.

## What can be done?

Anything you want! Implement own gates by extending the 'Quantum_Gate' module, play around with them, or try to implement special algorithms! Technically, this simulation should be quantum Turing complete ;-). This project was done by me some time ago as a base for a quantum poker game, which I eventually abandoned. Maybe you want to do something like that? It's Ruby code, but porting it to C or any other programming language should not prove too difficult.
