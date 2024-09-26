classdef PurchaseGenerator < handle
    %   Generate a random purchase for a LiquidityPool
    %   If the Token is an algoritmic stablecoin two different stochastic
    %   models are implemented: one related to price stability, the other
    %   for peg loss situations
    
    properties
        Pool                                        LiquidityPool
        P                                           double
        sigma                                       double
        i                                           
        WalletBalanceGenerator                      WalletBalanceGenerator
        CrisisScenario                              double = 0
    end
    
    methods
        function generator = PurchaseGenerator(liquidityPool, length, ...
                initialP, initialSigma, walletBalanceGenerator)
            % PARAMS
            %   liquidity pool                      - LiquidityPool
            %   number of simulation iterations     - decimal
            %   starting probability                - double
            %   starting sigma                      - double
            %   wallet balance generator            - WalletBalanceGenerator
            
            generator.Pool = liquidityPool;
            generator.P = zeros(1, length);
            generator.P(1) = initialP;
            generator.sigma = initialSigma;
            generator.i = 1;
            generator.WalletBalanceGenerator = walletBalanceGenerator;
        end
        
        function [token, quantity] = rndPurchase(self, totalFreeTokenSupply, totalTokenSupply)
            % generate random tokens purchase

            % compute ratio between free and total tokens
            r = totalFreeTokenSupply / totalTokenSupply;
            
            % compute delta
            delta = self.computeDelta();
            % add delta to P
            self.i = self.i + 1;
            newP = self.P(self.i-1) + delta;
            
            % is the new P beetwen 0 and 1?
            if (newP > 1)
                self.P(self.i) = 1;
            elseif (newP < 0)
                self.P(self.i) = 0;
            else
                self.P(self.i) = newP;
            end
            
            % choose a n from a random uniform distribution
            n = rand(1,1);
            
            if (n < self.P(self.i))
                token = self.Pool.T_a;
                tokenPrice = self.Pool.getTokenPrice(self.Pool.T_a, 1);
            else
                token = self.Pool.T_b;
                tokenPrice = 1;
            end

            quantity = self.generateRandomQuantity(r, tokenPrice);
            
            if (token.is_equal(self.Pool.T_a) && quantity > totalFreeTokenSupply)
                quantity = totalFreeTokenSupply;
            end
                
        end
        
        function delta = computeDelta(self)
            % COMPUTE DELTA from a normal distribution
            
            normMean = 0;
            computedSigma = self.sigma;
            
            if (self.Pool.T_a.IsStablecoin == true)
                % get price deviation from peg
                priceDeviation = self.Pool.T_a.PEG - self.Pool.getTokenPrice(self.Pool.T_a, 1);
                
                if (priceDeviation > 0.05)
                    self.CrisisScenario = priceDeviation;
                    % the mean of the normal distribution is moved
                    computedSigma = computedSigma * 10;
                    normMean = priceDeviation * computedSigma;
                else
                    self.CrisisScenario = 0;
                end
            elseif (self.Pool.T_a.IsCollateral == true && self.CrisisScenario > 0)
                normMean =  self.CrisisScenario * computedSigma;
            end

            delta = normrnd(normMean, computedSigma);
            
        end
        
        function quantity = generateRandomQuantity(self, r, tokenPrice)            
            % select a random wallet from the wallets distribution
            randomWalletBalance = ...
                self.WalletBalanceGenerator.rndWalletBalance();

            realBalance = (randomWalletBalance / tokenPrice) * r;
            
            % set sigma
            if self.Pool.T_a.IsCollateral == true
                sigmaQuantity = realBalance;
                sigmaQuantity = sigmaQuantity * self.sigma*10000;
            else
                sigmaQuantity = realBalance/100;
                sigmaQuantity = sigmaQuantity * self.sigma*10000;
            end
            % compute price deviation from peg
            if (self.CrisisScenario > 0)
                sigmaQuantity = realBalance / 5;
            end
            
            if realBalance > 0
                % compute the truncated normal distribution
                untruncated = makedist('Normal', 0, sigmaQuantity);
                tnd = truncate(untruncated, 0, realBalance);

                % get random quantity
                quantity = random(tnd, 1, 1);
            else
                quantity = 0;
            end

        end

        function setNewSigma(self, newSigma)
            self.sigma = newSigma;
        end
        
    end
end

