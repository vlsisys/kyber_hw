import os
from CompactFIPS202 import *
from hashlib import sha3_256, sha3_512, shake_128, shake_256
from polynomials import *
from modules import *
from ntt_helper import NTTHelperKyber
try:
    from aes256_ctr_drbg import AES256_CTR_DRBG
except ImportError as e:
    print("Error importing AES CTR DRBG. Have you tried installing requirements?")
    print(f"ImportError: {e}\n")
    print("Kyber will work perfectly fine with system randomness")
    

DEFAULT_PARAMETERS = {
    "kyber_512" : {
        "n" : 256, 
        "k" : 2, 
        "q" : 3329, 
        "eta_1" : 3, 
        "eta_2" : 2, 
        "du" : 10, 
        "dv" : 4, 
    },
    "kyber_768" : {
        "n" : 256,
        "k" : 3,
        "q" : 3329,
        "eta_1" : 2,
        "eta_2" : 2,
        "du" : 10,
        "dv" : 4,
    },
    "kyber_1024" : {
        "n" : 256,
        "k" : 4,
        "q" : 3329,
        "eta_1" : 2,
        "eta_2" : 2,
        "du" : 11,
        "dv" : 5,
    }
}

class Kyber:
    def __init__(self, parameter_set):
        self.n = parameter_set["n"] # Maximum degree of the used polynomials
        self.k = parameter_set["k"] # Number of polynomials per vector or the number of polynomials in the key
        self.q = parameter_set["q"] # Modulus for numbers
        self.eta_1 = parameter_set["eta_1"] # Control how big coefficients of “small” polynomials can be (Noise parameters)
        self.eta_2 = parameter_set["eta_2"] # Control how big coefficients of “small” polynomials can be (Noise parameters)
        self.du = parameter_set["du"] # Control how much u get compressed
        self.dv = parameter_set["dv"] # Control how much v get compressed
        
        self.R = PolynomialRing(self.q, self.n, ntt_helper=NTTHelperKyber) # An instance of PolynomialRing class
        self.M = Module(self.R) # An instance of Module class
        
        self.drbg = None # Deterministic Random Bit Generator (DRBG) represents an instance of the AES256_CTR_DRBG class
        self.random_bytes = os.urandom
        
    # Set the seed and random bytes 
    def set_drbg_seed(self, seed): 
        """
        Setting the seed switches the entropy source
        from os.urandom to AES256 CTR DRBG
        
        Note: requires pycryptodome for AES impl.
        (Seemed overkill to code my own AES for Kyber)
        """
        self.drbg = AES256_CTR_DRBG(seed)
        self.random_bytes = self.drbg.random_bytes

    # Reset the seed with existing seed value
    def reseed_drbg(self, seed): 
        """
        Reseeds the DRBG, errors if a DRBG is not set.
        
        Note: requires pycryptodome for AES impl.
        (Seemed overkill to code my own AES for Kyber)
        """
        if self.drbg is None:
            raise Warning(f"Cannot reseed DRBG without first initialising. Try using `set_drbg_seed`")
        else:
            self.drbg.reseed(seed)
        
    # Extended Output Function (XOF): Hash the bytes32 + a + b values (bytes) using the shake_128 algorithm and produce the output with specified "length"
    @staticmethod
    def _xof(self, bytes32, a, b, length):
        """
        XOF: B^* x B x B -> B*
        """

        input_bytes = bytes32 + a + b
        if len(input_bytes) != 34:
            raise ValueError(f"Input bytes should be one 32 byte array and 2 single bytes.")

        self._xof_bytes32       = bytes32
        self._xof_a             = a
        self._xof_b             = b
        self._xof_length        = length
        self._xof_input_bytes   = input_bytes

        #print(f'SHAKE128:{len(input_bytes)}, {length}')
        return shake_128(input_bytes).digest(length)
        # return SHAKE128(input_bytes, length)
    
    # Pseudorandom Function (PRF): Hash the s + b values (bytes) using the shake_256 algorithm and product the output with specified "length"
    @staticmethod  
    def _prf(s, b, length): 
        """
        PRF: B^32 x B -> B^*
        """
        input_bytes = s + b
        if len(input_bytes) != 33:
            raise ValueError(f"Input bytes should be one 32 byte array and one single byte.")
        
        #print(f'SHAKE256:{len(input_bytes)}, {length}')
        return shake_256(input_bytes).digest(length)
        # return SHAKE256(input_bytes, length)
    
    # Hash the input_bytes by sha3_256 algorithm
    @staticmethod
    def _h(input_bytes): 
        """
        H: B* -> B^32
        """
        #print(f'SHA3_256:{len(input_bytes)}')
        return sha3_256(input_bytes).digest() # 32 bytes long
        # return SHA3_256(input_bytes)
    
    # Hash the input_bytes by sha3_512 algorithm
    @staticmethod  
    def _g(input_bytes): 
        """
        G: B* -> B^32 x B^32
        """
        output = sha3_512(input_bytes).digest() # 64 bytes long
        # output = SHA3_512(input_bytes)
        #print(f'SHA3_512:{len(input_bytes)}')
        return output[:32], output[32:]
    
    # Key Derivation Function (KDF)
    @staticmethod
    def _kdf(input_bytes, length):
        """
        KDF: B^* -> B^*
        """
        #print(f'SHAKE256:{len(input_bytes)}, {length}')
        return shake_256(input_bytes).digest(length)
        # return SHAKE256(input_bytes, length)
    
    # Generate an error vector that consists of "self.k" polynomials 
    # sigma: A byte sequence used as an input to a pseudo-random function (PRF).
    # eta: A parameter controlling the noise distribution.
    # N: A counter used to generate different error vectors. N is an integer value, typically ranging from 0 to 255. In the context of cryptographic algorithms like Kyber, N is often used as a counter or index.
    # is_ntt: A boolean flag indicating whether the result should be in NTT (Number-Theoretic Transform) form.
    def _generate_error_vector(self, sigma, eta, N, is_ntt=False):
        """
        Helper function which generates an element in the
        module from the Centered Binomial Distribution.
        """
        elements = [] # Error vector
        for _ in range(self.k):
            input_bytes = self._prf(sigma, bytes([N]), 64*eta) # Generate an input bytes
            poly = self.R.cbd(input_bytes, eta, is_ntt=is_ntt) # Create a polynomial
            elements.append(poly)
            N = N + 1
        v = self.M(elements).transpose() # An instance of Matrix class (Has been transposed from shape (k, 1) to shape (1, k))
        v_norm = self.M(elements)

        """For Test"""
        self._generate_error_vector_v = v
        self._generate_error_vector_v_norm = v_norm
        self._generate_error_vector_N = N
        self._generate_error_vector_sigma = sigma
        self._generate_error_vector_eta = eta

        return v, N
        
    # Generate an element of size "k" x "k" from a seed "rho". It's used to create matrices during the key generation process
    # rho: A byte sequence used as a seed for generating the matrix.
    # transpose: A boolean flag indicating whether the matrix should be constructed as a transpose.
    # is_ntt: A boolean flag indicating whether the result should be in NTT (Number-Theoretic Transform) form.
    def _generate_matrix_from_seed(self, rho, transpose=False, is_ntt=False):
        """
        Helper function which generates an element of size
        k x k from a seed `rho`.
        
        When `transpose` is set to True, the matrix A is
        built as the transpose.
        """
        A = []
        for i in range(self.k):
            row = []
            for j in range(self.k):
                if transpose:
                    input_bytes = self._xof(self, rho, bytes([i]), bytes([j]), 3*self.R.n) # Generate a ninput bytes
                else:
                    input_bytes = self._xof(self, rho, bytes([j]), bytes([i]), 3*self.R.n) # Generate a ninput bytes
                aij = self.R.parse(input_bytes, is_ntt=is_ntt) # Create a polynomial from the byte stream
                row.append(aij)
            A.append(row)
        return self.M(A) # An instance of Matrix class
        
    def _cpapke_keygen(self):
        """
        Algorithm 4 (Key Generation)
        https://pq-crystals.org/kyber/data/kyber-specification-round3-20210804.pdf
        
        Input:
            None
        Output:
            Secret Key (12*k*n) / 8      bytes
            Public Key (12*k*n) / 8 + 32 bytes
        """
        print(f'-------------------------')
        print(f'Kyber Key Generation')
        print(f'-------------------------')
        # Generate random value, hash and split
        d = self.random_bytes(32)
        rho, sigma = self._g(d)
        # Set counter for PRF
        N = 0
        
        # Generate the matrix A ∈ R^kxk
        A = self._generate_matrix_from_seed(rho, is_ntt=True)
        
        # Generate the error vector s ∈ R^k
        s, N = self._generate_error_vector(sigma, self.eta_1, N)
        s.to_ntt()
        
        # Generate the error vector e ∈ R^k
        e, N = self._generate_error_vector(sigma, self.eta_1, N)
        e.to_ntt() 
                           
        # Construct the public key
        t = (A @ s).to_montgomery() + e
        
        # Reduce vectors mod^+ q
        t.reduce_coefficents()
        s.reduce_coefficents()
        
        # Encode elements to bytes and return
        pk = t.encode(l=12) + rho
        sk = s.encode(l=12)
        return pk, sk
        
    def _cpapke_enc(self, pk, m, coins):
        """
        Algorithm 5 (Encryption)
        https://pq-crystals.org/kyber/data/kyber-specification-round3-20210804.pdf
        
        Input:
            pk: public key
            m:  message ∈ B^32
            coins:  random coins ∈ B^32
        Output:
            c:  ciphertext
        """
        print(f'-------------------------')
        print(f'Kyber Encryption')
        print(f'-------------------------')
        N = 0
        rho = pk[-32:]
        
        # Convert public_key (bytes array) to a matrix under ntt form
        tt = self.M.decode(pk, 1, self.k, l=12, is_ntt=True)        
        
        # Encode message as polynomial
        print(f':::Decompressing u')
        m_poly = self.R.decode(m, l=1).decompress(1)
        
        # Generate the matrix A^T ∈ R^(kxk)
        At = self._generate_matrix_from_seed(rho, transpose=True, is_ntt=True)
        
        # Generate the error vector r ∈ R^k
        r, N = self._generate_error_vector(coins, self.eta_1, N)
        r.to_ntt()
        
        # Generate the error vector e1 ∈ R^k
        e1, N = self._generate_error_vector(coins, self.eta_2, N)
        
        # Generate the error polynomial e2 ∈ R
        input_bytes = self._prf(coins,  bytes([N]), 64*self.eta_2)
        e2 = self.R.cbd(input_bytes, self.eta_2)
        
        # Module/Polynomial arithmetic 
        u = (At @ r).from_ntt() + e1
        v = (tt @ r)[0][0].from_ntt()
        v = v + e2 + m_poly
        
        # Ciphertext to bytes
        print(f':::Compressing u')
        c1 = u.compress(self.du).encode(l=self.du)
        print(f':::Compressing v')
        c2 = v.compress(self.dv).encode(l=self.dv)
        
        return c1 + c2
    
    def _cpapke_dec(self, sk, c):
        """
        Algorithm 6 (Decryption)
        https://pq-crystals.org/kyber/data/kyber-specification-round3-20210804.pdf
        
        Input:
            sk: secret key
            c:  message ∈ B^32
        Output:
            m:  message ∈ B^32
        """
        print(f'-------------------------')
        print(f'Kyber Decryption')
        print(f'-------------------------')
        # Split ciphertext to vectors
        index = self.du * self.k * self.R.n // 8
        c2 = c[index:]
        
        # Recover the vector u and convert to NTT form
        print(f':::Decompressing u')
        u = self.M.decode(c, self.k, 1, l=self.du).decompress(self.du)
        u.to_ntt()
        
        # Recover the polynomial v
        print(f':::Decompressing v')
        v = self.R.decode(c2, l=self.dv).decompress(self.dv)
        
        # s_transpose (already in NTT form)
        st = self.M.decode(sk, 1, self.k, l=12, is_ntt=True)
        
        # Recover message as polynomial
        m = (st @ u)[0][0].from_ntt()
        m = v - m
        
        # Return message as bytes
        print(f':::Compressing v')
        return m.compress(1).encode(l=1)
    
    def keygen(self):
        """
        Algorithm 7 (CCA KEM KeyGen)
        https://pq-crystals.org/kyber/data/kyber-specification-round3-20210804.pdf
        
        Output:
            pk: Public key
            sk: Secret key
            
        """
        # Note, although the paper gens z then
        # pk, sk, the implementation does it this
        # way around, which matters for deterministic
        # randomness...
        pk, _sk = self._cpapke_keygen()
        z = self.random_bytes(32)
        
        # sk = sk' || pk || H(pk) || z
        sk = _sk + pk + self._h(pk) + z
        return pk, sk
        
    def enc(self, pk, key_length=32):
        """
        Algorithm 8 (CCA KEM Encapsulation)
        https://pq-crystals.org/kyber/data/kyber-specification-round3-20210804.pdf
        
        Input: 
            pk: Public Key
        Output:
            c:  Ciphertext
            K:  Shared key
        """
        m = self.random_bytes(32)
        m_hash = self._h(m)
        Kbar, r = self._g(m_hash + self._h(pk))
        c = self._cpapke_enc(pk, m_hash, r)
        K = self._kdf(Kbar + self._h(c), key_length)
        return c, K

    def dec(self, c, sk, key_length=32):
        """
        Algorithm 9 (CCA KEM Decapsulation)
        https://pq-crystals.org/kyber/data/kyber-specification-round3-20210804.pdf
        
        Input: 
            c:  ciphertext
            sk: Secret Key
        Output:
            K:  Shared key
        """
        # Extract values from `sk`
        # sk = _sk || pk || H(pk) || z
        index = 12 * self.k * self.R.n // 8
        _sk =  sk[:index]
        pk = sk[index:-64]
        hpk = sk[-64:-32]
        z = sk[-32:]
        
        # Decrypt the ciphertext
        _m = self._cpapke_dec(_sk, c)
        
        # Decapsulation
        _Kbar, _r = self._g(_m + hpk)
        _c = self._cpapke_enc(pk, _m, _r)
        
        # if decapsulation was successful return K
        if c == _c:
            return self._kdf(_Kbar + self._h(c), key_length)
        # Decapsulation failed... return random value
        return self._kdf(z + self._h(c), key_length)

# Initialise with default parameters for easy import
Kyber512 = Kyber(DEFAULT_PARAMETERS["kyber_512"])
Kyber768 = Kyber(DEFAULT_PARAMETERS["kyber_768"])
Kyber1024 = Kyber(DEFAULT_PARAMETERS["kyber_1024"])