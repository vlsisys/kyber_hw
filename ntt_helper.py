"""
The class `NTTHelper` has been defined to allow for the 
`Polynomial` class to have some `n=256` NTT help for 
Kyber. This is ok code, but it doesnt generalise nicely.

TODOs: 

- Build structure to allow this to generalise away from n=256.
- Allow for kyber and dilithium NTT in one file. 

"""

NTT_PARAMETERS = {
    "kyber" : {
        "q"             : 3329,
        "mont_r"        : 2285,  # 2^16 % q
        "mont_r2"       : 1353,  # 2^32 % q
        "mont_r_inv"    : 169,   # (1 / 2^16) % q
        "mont_mask"     : 65535, # 2^16 - 1,
        "q_inv"         : 3327,  # -1 / 3329 ^ 2^16,
        "root_of_unity" : 17,
        # NTT_ZETAS  : [(mont_r * pow(root_of_unity,  br(i,7), q)) % q for i in range(128)],
        "zetas" : [2285, 2571, 2970, 1812, 1493, 1422, 287, 202, 3158, 622, 1577, 182, 962, 2127, 1855, 1468, 
                     573, 2004, 264, 383, 2500, 1458, 1727, 3199, 2648, 1017, 732, 608, 1787, 411, 3124, 1758, 
                     1223, 652, 2777, 1015, 2036, 1491, 3047, 1785, 516, 3321, 3009, 2663, 1711, 2167, 126, 1469, 
                     2476, 3239, 3058, 830, 107, 1908, 3082, 2378, 2931, 961, 1821, 2604, 448, 2264, 677, 2054, 
                     2226, 430, 555, 843, 2078, 871, 1550, 105, 422, 587, 177, 3094, 3038, 2869, 1574, 1653, 3083, 
                     778, 1159, 3182, 2552, 1483, 2727, 1119, 1739, 644, 2457, 349, 418, 329, 3173, 3254, 817, 
                     1097, 603, 610, 1322, 2044, 1864, 384, 2114, 3193, 1218, 1994, 2455, 220, 2142, 1670, 2144, 
                     1799, 2051, 794, 1819, 2475, 2459, 478, 3221, 3021, 996, 991, 958, 1869, 1522, 1628],
        "f" : 1441,              # 2^32 / 128 % q
    },
}


class NTTHelper():
    def __init__(self, parameter_set):
        self.q          = parameter_set["q"]
        self.mont_r     = parameter_set["mont_r"]
        self.mont_r2    = parameter_set["mont_r2"]
        self.mont_r_inv = parameter_set["mont_r_inv"]
        self.q_inv      = parameter_set["q_inv"]
        self.zetas      = parameter_set["zetas"]
        self.f          = parameter_set["f"]
        
    # A static method that performs bit reversal on an unsigned "k"-bit integer "i"
    # Ex: br(10, 8) => i = 10 => i_binary = 1010 => k_bits_i_binary = 0000 1010 => result = 0101 0000
    @staticmethod
    def br(i, k):
        """
        bit reversal of an unsigned k-bit integer
        """
        bin_i = bin(i & (2**k - 1))[2:].zfill(k)

        return int(bin_i[::-1], 2)

    # Performs a Montgomery reduction operation on an input value "a". 
    # This operation involves multiplying a by the Montgomery factor "mont_r_inv" and taking the result modulo "q"
    def montgomery_reduce(self, a):
        """
        This is not proper mont. reduction.
        But this is faster than the normal impl
        because python is weird.
        
        Proper impl is commented out at the bot.
        of the file...
        
        a -> R^(-1) a mod q
        """
        return a * self.mont_r_inv % self.q
        
    # Converts the coefficients of a polynomial "poly" to Montgomery form
    def to_montgomery(self, poly):
        poly.coeffs = [self.ntt_mul(self.mont_r2, c) for c in poly.coeffs]

        return poly

    # Computes "a" modulo "q"
    def reduce_mod_q(self, a):
        """
        return a mod q
        """
        return a % self.q
        
    # Performs a Barrett reduction operation on an input value "a". 
    # This operation is an alternative to "reduce_mod_q" but may be slower
    def barrett_reduce(self,a):
        """
        This should be faster, but because
        python, the function `reduce_mod_q` is faster...
        
        a mod q in -(q-1)/2, ... ,(q-1)/2
        """
        v = ((1 << 26) + self.q // 2) // self.q
        t = (v * a + (1 << 25)) >> 26
        t = t * self.q

        return (a - t)
        
    # Multiplies two values "a" and "b" and then performs a Montgomery reduction
    def ntt_mul(self, a, b):
        """
        Multiplication then Montgomery reduction
        
        Ra * Rb -> Rab
        """
        c = a * b

        return self.montgomery_reduce(c)
    
    # Performs NTT-based multiplication of polynomial coefficients "a0", "a1", "b0", and "b1" using the provided "zeta" value
    def ntt_base_multiplication(self, a0, a1, b0, b1, zeta):
        r0  = self.ntt_mul(a1, b1)
        r0  = self.ntt_mul(r0, zeta)
        r0 += self.ntt_mul(a0, b0)
        r1  = self.ntt_mul(a0, b1)
        r1 += self.ntt_mul(a1, b0)

        return r0, r1
        
    # Multiplies two sets of polynomial coefficients "f_coeffs" and "g_coeffs" using NTT-based multiplication
    def ntt_coefficient_multiplication(self, f_coeffs, g_coeffs):
        new_coeffs = []
        for i in range(64):
            r0, r1 = self.ntt_base_multiplication(
                                f_coeffs[4*i+0], f_coeffs[4*i+1],
                                g_coeffs[4*i+0], g_coeffs[4*i+1],
                                self.zetas[64+i])
            r2, r3 = self.ntt_base_multiplication(
                                f_coeffs[4*i+2], f_coeffs[4*i+3],
                                g_coeffs[4*i+2], g_coeffs[4*i+3],
                                -self.zetas[64+i])
            new_coeffs += [r0, r1, r2, r3]

        return new_coeffs
        
    # Converts a polynomial to Number Theoretic Transform (NTT) form
    def to_ntt(self, poly):
        """
        Convert a polynomial to number-theoretic transform (NTT) form in place
        The input is in standard order, the output is in bit-reversed order.
        NTT_ZETAS also has the Montgomery factor 2^16 included, so NTT 
        additionally maps to Montgomery domain.
        
        Only implemented (currently) for n = 256
        """
        if poly.is_ntt:
            raise ValueError("Cannot convert NTT form polynomial to NTT form")

        k, l = 1, 128
        coeffs = poly.coeffs
        while l >= 2:
            print(f'l          : {l}')
            start = 0
            while start < 256:
                zeta = self.zetas[k]
                print(f'start      : {start}')
                print(f'k          : {k}')
                print(f'zeta       : {zeta}')
                print(f'coeffs     : {coeffs}')
                k = k + 1
                for j in range(start, start + l):
                    t = self.ntt_mul(zeta, coeffs[j+l])
                    print(f'index      : {j:3},{j+l:3}')
                    coeffs[j+l] = coeffs[j] - t
                    coeffs[j]   = coeffs[j] + t
                start = l + (j + 1)
            l = l >> 1
            print(f'-----------------------')

        poly.is_ntt = True

        return poly
    
    # Converts a polynomial from NTT form and performs a multiplication by a Montgomery factor
    def from_ntt(self, poly):
        """
        Convert a polynomial from number-theoretic transform (NTT) form in place
        and multiplication by Montgomery factor 2^16.
        The input is in bit-reversed order, the output is in standard order.
        
        Because of the montgomery multiplication, we have:
            f != f.to_ntt().from_ntt()
            f = (1/2^16) * f.to_ntt().from_ntt()
        
        To recover f we do
            f == f.to_ntt().from_ntt().from_montgomery()
            
        Only implemented (currently) for n = 256
        """
        if not poly.is_ntt:
            raise ValueError("Can only convert from a polynomial in NTT form")
            
        l, l_upper = 2, 128
        k = l_upper - 1
        coeffs = poly.coeffs
        while l <= 128:
            start = 0
            while start < poly.parent.n:
                zeta = self.zetas[k]
                k = k - 1
                for j in range(start, start+l):
                    t = coeffs[j]
                    coeffs[j]   = self.reduce_mod_q(t + coeffs[j+l])
                    coeffs[j+l] = coeffs[j+l] - t
                    coeffs[j+l] = self.ntt_mul(zeta, coeffs[j+l])
                start = j + l + 1
            l = l << 1

        for j in range(poly.parent.n):
            coeffs[j] = self.ntt_mul(coeffs[j], self.f)
            
        poly.is_ntt = False
        
        return poly
    
NTTHelperKyber = NTTHelper(NTT_PARAMETERS["kyber"])



# def __montgomery_reduce_old(a):
#     """
#     This should be faster, but because
#     python, the below function `montgomery_reduce`
#     is faster...
    
#     a -> R^(-1) a mod q
#     """
#     u = ((a & self.mont_mask) * self.q_inv) & self.mont_mask
#     t = a + u*self.q
#     t = t >> 16
#     if t >= self.q:
#         t = t - self.q
#     return t