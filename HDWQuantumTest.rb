require './HDWQuantum.rb'

size = 5
qreg = Quantum_Register.new(size, 0b11000)

qreg.apply_one_qubit_gate(Quantum_Gate::Hadamard, 1)
qreg.apply_two_qubit_gate(Quantum_Gate::C_Not, 1, 4)

qreg.output_state_vector

result = qreg.measure
print "%0#{size}b" % result
