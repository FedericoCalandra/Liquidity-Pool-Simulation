classdef LiquidityPool < handle
    %LIQUIDITY POOL model
    
    properties
        T_a  Token                                                          % token A type
        T_b  Token                                                          % token B type
        Q_a  double  {mustBePositive}                                       % token A balance
        Q_b  double  {mustBePositive}                                       % token B balance
        f    double  {mustBeNonnegative, mustBeLessThan(f, 1)} = 0          % fee : 0 <= f < 1
        K    double                                                         % invariant : K = Q_a * Q_b
    end
    
    methods
        function pool = LiquidityPool(varargin)
            %LiquidityPool() Construct an instance of this class
            pool.T_a = varargin{1};
            pool.T_b = varargin{2};
            pool.Q_a = varargin{3};
            pool.Q_b = varargin{4};
            if nargin > 4
                pool.f = varargin{5};
            end
            
            pool.K = pool.Q_a * pool.Q_b;
        end
        
        function [newQ_a, newQ_b] = swap(self, token, quantity)
            % Performs a swap operation within the pool
            
            fee = abs(quantity * self.f);
            
            if token.is_equal(self.T_a)
                self.Q_a = self.Q_a + quantity;
                self.Q_b = self.K / (self.Q_a - fee);
            elseif token.is_equal(self.T_b)
                self.Q_b = self.Q_b + quantity;
                self.Q_a = self.K / (self.Q_b - fee);
            else
                if (self.Q_a + quantity - fee) <= 0 || (self.Q_b + quantity - fee) <= 0
                    error("ERROR in swap()\ntoken balance cannot be negative");
                else
                    error("ERROR in swap()\nwrong token type");
                end
            end
            
            % update K (due to fees)
            self.K = self.Q_a * self.Q_b;
            
            % output
            newQ_a = self.Q_a;
            newQ_b = self.Q_b;
        end
        
        function k = getKValue(self)
            k = self.K;  
        end
        
        function v = getTokenValueWRTOtherToken(self, token)
            if token.is_equal(self.T_a)
                v = self.K / ((self.Q_a^2) + self.Q_a);
            elseif token.is_equal(self.T_b)
                v = self.K / ((self.Q_b^2) + self.Q_b);
            else
                error("ERROR in getTokenValueWRTOtherToken()\nwrong token type");
            end
        end
        
        function p = getTokenPrice(self, token, otherTokenPrice)
            % Returns token price in this liquidity pool instance
            v = getTokenValueWRTOtherToken(self, token);
            p = v * otherTokenPrice;
        end
        
        function q = computeSwapValue(self, token, quantity)
            fee = abs(quantity * self.f);
            
            if token.is_equal(self.T_a) && (self.Q_a + quantity - fee) > 0
                newQ_a = self.Q_a + quantity;
                q = self.Q_b - self.K / (newQ_a - fee);
            elseif token.is_equal(self.T_b) && (self.Q_b + quantity - fee) > 0
                newQ_b = self.Q_b + quantity;
                q = self.Q_a - self.K / (newQ_b - fee);
            else
                if (self.Q_a + quantity - fee) <= 0 || (self.Q_b + quantity - fee) <= 0
                    error("ERROR in swap()\ntoken balance cannot be negative");
                else
                    error("ERROR in swap()\nwrong token type");
                end
            end
        end
        
    end
end







