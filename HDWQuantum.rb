require 'matrix.rb'
require 'complex.rb' if RUBY_VERSION[0] == "1"
include Math

class Matrix

	# Used to apply more than one matrix at a time to a quantum register
	def kronecker_product(other_matrix)
		@new_matrix = Matrix.build(self.row_size*other_matrix.row_size, self.column_size*other_matrix.column_size) {
			|i, j| self[i / other_matrix.row_size, j / other_matrix.column_size]*other_matrix[i % other_matrix.row_size, j % other_matrix.column_size]
		}
		return @new_matrix
	end
	
end

HEAD = Matrix[[0],[1]]	# Represents base state |1>
TAIL = Matrix[[1],[0]]	# Represents base state |0>

module Quantum_Gate

	INV_SQRT_2 = 1.0 / sqrt(2.0)

	# Trivial matrices
	Unity = Matrix.identity(2)
	Zero = Matrix.zero(2)
	
	# Base matrices or projection operators, e.g. Base_01 representing |0><1|
	Base_00 = TAIL.kronecker_product(TAIL.transpose)
	Base_01 = TAIL.kronecker_product(HEAD.transpose)
	Base_10 = HEAD.kronecker_product(TAIL.transpose)
	Base_11 = HEAD.kronecker_product(HEAD.transpose)
	Bases = [[Base_00, Base_01],[Base_10, Base_11]]

	# Helper matrices, needed for Sqrt_Swap
	Helper_A = Matrix[[1, 0],[0, 0.5*(1 + Complex::I)]]
	Helper_B = Matrix[[0.5*(1 + Complex::I), 0],[0, 1]]
	
	# Pauli gates
	Pauli_X = Not = Matrix[[0, 1],[1, 0]]
	Pauli_Y = Matrix[[0, -Complex::I],[Complex::I, 0]]
	Pauli_Z = Matrix[[1, 0],[0, -1]]
	
	# Hadamard gate, useful for superpositions
	Hadamard = Matrix[[1, 1],[1,-1]]*INV_SQRT_2

	# Rotation gates
	Rotation_X_90 = Matrix[[1, -Complex::I],[-Complex::I, 1]]*INV_SQRT_2
	Rotation_Y_90 = Matrix[[1, -1],[1, 1]]*INV_SQRT_2
	Rotation_Phase_90 = S_Gate = Matrix[[1, 0],[0, Complex::I]]
	Rotation_Phase_45 = T_Gate = Matrix[[1, 0],[0, Complex.polar(1, PI/4.0)]]
	
	# Other 1-Qubit-Gates
	Sqrt_Not = Pauli_X**(0.5)	# Nomenclature is not consistent between many sources, so pay attention when using this gate
	
	# 2-Qubit-Gates, created with 2x2-Arrays of 2x2-Matrices, with scheme [[0,1],[2,3]] for the indices
	C_Not = [[Unity, Zero],[Zero, Not]]
	Swap = [[Base_00, Base_10],[Base_01, Base_11]]
	Sqrt_Swap = [[Helper_A, Base_10*(0.5*(1 - Complex::I))],[Base_01*(0.5*(1 - Complex::I)), Helper_B]]
	
	# 3-Qubit-Gates, created with 4x4-Arrays of 2x2-Matrices, scheme similar to 2-Qubit-Gates
	C_C_Not = Toffoli = [[Unity, Zero, Zero, Unity],[Zero]*4,[Zero]*4,C_Not.flatten]
	C_Swap = Fredkin = [[Unity, Zero, Zero, Unity],[Zero]*4,[Zero]*4,Swap.flatten]
	
end

class Quantum_Register

	def initialize(size, position)	# Position is equivalent to the binary value of the state vector, |1>|0>|0> will be 4 or 0b100, |0>|0> will be 0 or 0b00, etc.
		if 2**size <= position then
			raise "ERROR: Position bigger than size of register."
		end
		@size = size
		@state_vector = Matrix.build(2**size, 1) {|i| i == position ? 1 : 0}	# The state at the beginning should be classical
	end
	
	def apply_matrix(matrix)
		@state_vector = matrix*@state_vector
	end
	
	def apply_one_qubit_gate(gate, qubit)
		qubit = @size - qubit - 1	# So the qubit actually represents the classical bit
		matrix = Matrix.identity(2**(qubit))	# Fill the final matrix up with unity matrices to apply no changes to unaffected qubits
		matrix = matrix.kronecker_product(gate)
		if @size - 1 - qubit > 0 then	# Unity matrices of negative size will lead to errors, so check for that
			matrix = matrix.kronecker_product(Matrix.identity(2**(@size - 1 - qubit)))	# Again, use unity matrices to get the desired size of the final matrix
		end
		apply_matrix(matrix)
	end
	
	def apply_two_qubit_gate(gate, qubit_1, qubit_2)
		qubit_1 = @size - qubit_1 - 1
		qubit_2 = @size - qubit_2 - 1
		qubit_min = [qubit_1, qubit_2].min
		qubit_max = [qubit_1, qubit_2].max
		collected_matrices = []
		matrix = Matrix.identity(2**(qubit_min))
		raise "ERROR: Parameters are equal." if qubit_1 == qubit_2 
		0.upto(1) do |i|
			0.upto(1) do |j|
				sub_matrix = (qubit_1 < qubit_2 ? Quantum_Gate::Bases[i][j] : gate[i][j])	# Order of qubit arguments is important for Kronecker product order
				if qubit_max - qubit_min - 1 > 0 then
					sub_matrix = sub_matrix.kronecker_product(Matrix.identity(2**(qubit_max - qubit_min - 1)))
				end
				sub_matrix = sub_matrix.kronecker_product((qubit_1 < qubit_2 ? gate[i][j] : Quantum_Gate::Bases[i][j]))
				collected_matrices.push(sub_matrix)
			end
		end
		collected_matrix = collected_matrices[0]
		1.upto(3) {|n| collected_matrix += collected_matrices[n]}
		matrix = matrix.kronecker_product(collected_matrix)
		if @size - 1 - qubit_max > 0 then
			matrix = matrix.kronecker_product(Matrix.identity(2**(@size - 1 - qubit_max)))
		end
		apply_matrix(matrix)
	end
	
	def apply_three_qubit_gate(gate, qubit_1, qubit_2, qubit_3)	# Technically this could be extended to more than three qubits
		qubit_1 = @size - qubit_1 - 1
		qubit_2 = @size - qubit_2 - 1
		qubit_3 = @size - qubit_3 - 1
		qubit_first, qubit_second, qubit_third = *[qubit_1, qubit_2, qubit_3].sort
		collected_matrices = []
		matrix = Matrix.identity(2**(qubit_first))
		raise "ERROR: Parameters are equal." if qubit_1 == qubit_2 || qubit_2 == qubit_3 || qubit_3 == qubit_1
		0.upto(1) do |i|	# Could be done with one upto-loop and some binary numbers
			0.upto(1) do |j|
				0.upto(1) do |k|
					0.upto(1) do |l|
						bin_num = "#{i}#{j}#{k}#{l}".to_i(2)	# Convert indices into decimal number to properly address the gate entries
						sub_matrix = case qubit_first
							when qubit_1 then Quantum_Gate::Bases[i][j]
							when qubit_2 then Quantum_Gate::Bases[k][l]
							when qubit_3 then gate[bin_num / 4][bin_num % 4]
						end
						if qubit_second - qubit_first - 1 > 0 then
							sub_matrix = sub_matrix.kronecker_product(Matrix.identity(2**(qubit_second - qubit_first - 1)))
						end
						next_sub_matrix = case qubit_second
							when qubit_1 then Quantum_Gate::Bases[i][j]
							when qubit_2 then Quantum_Gate::Bases[k][l]
							when qubit_3 then gate[bin_num / 4][bin_num % 4]
						end
						sub_matrix = sub_matrix.kronecker_product(next_sub_matrix)
						if qubit_third - qubit_second - 1 > 0 then
							sub_matrix = sub_matrix.kronecker_product(Matrix.identity(2**(qubit_third - qubit_second - 1)))
						end
						next_sub_matrix = case qubit_third
							when qubit_1 then Quantum_Gate::Bases[i][j]
							when qubit_2 then Quantum_Gate::Bases[k][l]
							when qubit_3 then gate[bin_num / 4][bin_num % 4]
						end
						sub_matrix = sub_matrix.kronecker_product(next_sub_matrix)
						collected_matrices.push(sub_matrix)
					end
				end
			end
		end
		collected_matrix = collected_matrices[0]
		1.upto(15) {|n| collected_matrix += collected_matrices[n]}
		matrix = matrix.kronecker_product(collected_matrix)
		if @size - 1 - qubit_third > 0 then
			matrix = matrix.kronecker_product(Matrix.identity(2**(@size - 1 - qubit_third)))
		end
		apply_matrix(matrix)
	end
	
	def measure
		found = false
		while not found do
			test_value = rand(2**@size)
			if rand < @state_vector[test_value, 0].abs2 then	# Component of state vector equals square root of probability for corresponding classical state
				found = test_value
			end
		end
		return found
	end
	
	def output_state_vector
		0.upto(2**@size - 1) do |i|
			print "|%0#{@size}b" % i
			print ">   "
			puts @state_vector[i, 0]
		end
	end

end
