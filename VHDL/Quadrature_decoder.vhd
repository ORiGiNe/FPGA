library IEEE;
use IEEE.std_logic_1164.all;
-- use IEEE.numeric_std.all;
use IEEE.std_logic_arith.all;
-- use IEEE.std_logic_signed.all;

-- Realisation d'un decodeur de codeur incrémental à quadrature de phase.
-- Il y a deux signaux A et B qui correspondent aux deux phases:
--         |----------------------|
-- --------|                      |-------------------
--                    |------------------------|
-- -------------------|                        |------
-- <  1   > <    2   > <    3    > <     4    > <   1        <== Etats correspondants 
--
-- On peut ainsi incrémenter notre codeur en fonction des transitions:
-- 1 <-> 3 et 2 <-> 4 sont physiquement impossible
-- 1 -> 2 : +1      2 -> 1 : -1
-- 2 -> 3 : +1      3 -> 2 : -1
-- 3 -> 4 : +1      4 -> 3 : -1
-- 4 -> 1 : +1      1 -> 4 : -1
-- Les transistions qui correspondent à une evolution positive ( signal A en avance sur B) augmente de 1
-- et inversement.

entity Quadrature_decoder is
	generic ( 
		-- Nombre de ticks de clk entre deux sampling des signaux (Période d'échantillonnage). 
		-- Doit être suffisemment petit pour ne pas perdre d'information. 
		-- Et pas trop petit car on garde un historique des valeurs précedentes.
		-- Le mieux: determiner la frequence max : rapport de reduction (50) * vitesse max en tour de roue/s (4) * nombre de tick/tour de codeur (500) * 4. 
		-- Puis multiplier par 2 (critere de shanon) puis par 3 (vu qu'on a besoin d'au moins 3 valeurs dans shift), on obtient la frequence d'echantillonage (2.4MHZ).
		-- Il reste à faire frequence d'horloge (50MHZ) / frequence d'echantillonage pour obtenir la periode en tick de clk (1.2MHZ).
		sampling_interval : integer := 21 -- A peu pres la valeur pour le robot avec une vitesse max de 2 tours de roue par seconde (50/2.4 = 20.8). 
	);
	port (
		readdata                 : out std_logic_vector(15 downto 0);                    --        readdata
		clk                   	 : in  std_logic                     ;             --             clock.clk
		reset                    : in  std_logic                    := '0' ;             --             reset
		raz                      : in  std_logic                    := '0' ;             -- Remise A Zero du compteur
		A                        : in  std_logic                    ;             -- quadrature_signal
		B                        : in  std_logic                    ;             --                  
		errorOut                 : out std_logic                    := '0' ;              -- gestion des erreurs
		ledOut					    : out std_logic_vector(7 downto 0)
	);
end entity Quadrature_decoder;

architecture arch of Quadrature_decoder is

	signal counter  : signed(15 downto 0);--:= (others => '0'); -- std_logic_vector(15 downto 0)
	
	signal shiftA : std_logic_vector(2 downto 0);
	signal shiftB : std_logic_vector(2 downto 0); 
	
	signal voteA : std_logic;
	signal voteB : std_logic;
	signal voteA_previous : std_logic; 
	signal voteB_previous : std_logic;
	
	signal error : std_logic; -- pour gérer les cas impossibles = erreurs
	
	signal sortie : std_logic_vector(7 downto 0);
	
	--signal A : std_logic;
	--signal B : std_logic;
	--signal clk : std_logic;
	--signal ledOut: std_logic_vector(7 downto 0);
	
begin

	--A <= Encoder1_A;
	--B <= Encoder1_B;
	--clk <= CLOCK_50;
	--LEDG <= ledOut ;

	-- Ce process va permettre de sampler les signaux A et B
	-- On enregistre les 3 dernières valeurs dans shiftX afin de pouvoir corriger d'eventuel erreur de lecture lors du sampling (parasites sur la ligne par exemple)
	Shifter : process (clk, reset, A, B)
		variable clk_tick_counter : integer range 0 to sampling_interval - 1;
	begin
		if reset='0' then
			clk_tick_counter := 0;
			shiftA <= (others => A);
			shiftB <= (others => B);
		elsif Rising_Edge(clk) then
			if clk_tick_counter = sampling_interval - 1 then
				clk_tick_counter := 0;
				shiftA <= shiftA(1 downto 0) & A; -- On garde un historique des valeurs
				shiftB <= shiftB(1 downto 0) & B;
			else 
				clk_tick_counter := clk_tick_counter + 1;
			end if;
		end if;
	end process;
	
	-- On détermine la "vrai" valeur du signal en faisant la moyenne entière des 3 dernières valeurs. (On absorbe un eventuel sample foireux)
	voteA <= '1' when shiftA = "110" or shiftA = "101" or shiftA = "011" or shiftA = "111" else '0';
	voteB <= '1' when shiftB = "110" or shiftB = "101" or shiftB = "011" or shiftB = "111" else '0';
	
	Counter_proc : process (clk, reset, A, B, raz)
		variable code : std_logic_vector(3 downto 0);
		constant cstOne : signed(15 downto 0) := "0000000000000001";
	begin
		if reset='0' then
			error <= '0';
			counter <= (others => '0');
			voteA_previous <= A;
			voteB_previous <= B;
		elsif raz = '1' then
			error <= '1';
			counter <= (others => '0');
		elsif Rising_Edge(clk) then
			code := voteA & voteA_previous & voteB & voteB_previous;
			voteA_previous <= voteA;
			voteB_previous <= voteB;
			case code is
				when "0000" => null; -- aucun changement
				when "0001" => counter <= counter + cstOne; -- 4 -> 1
				when "0010" => counter <= counter - cstOne; -- 1 -> 4
				when "0011" => null; -- aucun changement
				when "0100" => null;--counter <= counter - cstOne; -- 2 -> 1 -- DIVISION
				when "0101" => error <= '1'; -- Les deux signaux se modifie en même temps -> impossible.	
				when "0110" => error <= '1'; -- Les deux signaux se modifie en même temps -> impossible.
				when "0111" => null;--counter <= counter + cstOne; -- 3 -> 4  -- DIVISION
				when "1000" => null;--counter <= counter + cstOne; -- 1 -> 2  -- DIVISION
				when "1001" => error <= '1'; -- Les deux signaux se modifie en même temps -> impossible.
				when "1010" => error <= '1'; -- Les deux signaux se modifie en même temps -> impossible.
				when "1011" => null;-- counter <= counter - cstOne; -- 4 -> 3 -- DIVISION
				when "1100" => null; -- aucun changement 
				when "1101" => counter <= counter - cstOne; -- 3 -> 2
				when "1110" => counter <= counter + cstOne; -- 2 -> 3
				when "1111" => null; -- aucun changement
				when others => null;
			end case;
		end if;
	end process;
	
	-- sortie <= CONV_STD_LOGIC_VECTOR(counter(7 downto 0), 8);  -- Pour voir octet faible
	sortie <= CONV_STD_LOGIC_VECTOR(counter, 16)(15 downto 8);   -- Pour voir octet fort
	readdata <= CONV_STD_LOGIC_VECTOR(counter, 16); -- On renvoit la valeur du compteur.
	ledOut <= sortie;
	errorOut <= error;
	
end architecture arch;
