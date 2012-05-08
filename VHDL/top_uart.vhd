-------------------------------------------------------------------------------------------------
 -- 1.0     ORiGiNe            2012          Modifications et nettoyage par ORiGiNe
-------------------------------------------------------------------------------------------------
 
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity 	TOP_UART is
	generic(
		encoderNumber: integer := 2 -- nombre de codeurs /!\ Si cette valeur est modifié, il faut modifier les assignements au debut de l'archi. /!\
	);
	port(

    -- Clocks
    CLOCK_50 : in std_logic;          -- 50 MHz
 
    -- Buttons and switches
    KEY : in std_logic_vector(1 downto 0);         -- Push buttons
    SW : in std_logic_vector(3 downto 0);          -- Switches
 
    -- LED displays
    LEDG : out std_logic_vector(7 downto 0);       -- Green LEDs
 
    -- RS-232 interface
    UART_TXD : out std_logic;                      -- UART transmitter
	ArduinoFlowCtrl1_N : in std_logic; -- depuis arduino : "envoie l'octet suivant"
	ArduinoFlowCtrl2_N : in std_logic; 
	
	-- Encoders interface (2 encoders)
	Encoder1_A : in std_logic;
	Encoder1_B : in std_logic;
	Encoder2_A : in std_logic;
	Encoder2_B : in std_logic
	
);
end TOP_UART;
 
architecture rtl of TOP_UART is
 
	component miniUART 
	port (
		SysClk   : in  Std_Logic;  -- System Clock
		Reset    : in  Std_Logic;  -- Reset input
		TxD      : out Std_Logic;
		DataIn   : in  Std_Logic_Vector(15 downto 0); -- 
		GetFirstByte : in  Std_Logic; -- depuis arduino, octet 1
		GetSecondByte : in  Std_Logic; -- depuis arduino, octet 2
		ByteSent  : out Std_Logic; -- verifie octet bien envoyé
		LoadOut  : out Std_Logic; -- debug de load
		NextLoadOut   : out  Std_Logic;
		FirstLoadOut   : out  Std_Logic); 
	end component;
	
	component Quadrature_decoder
	generic (
		sampling_interval : integer
	);
	port (
		readdata                 : out std_logic_vector(15 downto 0);       --        readdata
		clk                      : in  std_logic;             --             clock.clk
		reset                    : in  std_logic;             --             reset
		raz                      : in  std_logic;             -- Remise A Zero du compteur
		A                        : in  std_logic;             -- quadrature_signal
		B                        : in  std_logic;             --                  
		errorOut                 : out std_logic;
		ledOut					 : out std_logic_vector(7 downto 0)
	);
	end component;
	

	type CommState is (Idle, ArduinoEvent1, PrepareFirstByte, SendFirstByte, FirstByteSent, ArduinoEvent2, PrepareSecondByte, SendSecondByte); -- description des etats du protocole de communication
	type logicArray is array(1 to encoderNumber) of std_logic;
	type shortArray is array(1 to encoderNumber) of std_logic_vector(15 downto 0);
	

	signal ArduinoFlowCtrl : logicArray;
	signal Encoder_A : logicArray;
	signal Encoder_B : logicArray;
	signal DataToTransmit : shortArray;
	signal RAZencoder : logicArray; -- RAZ du codeur

	signal DataToTransmitBuffer : std_logic_vector(15 downto 0); -- le meme mais bufferisé
	signal NewRequest : std_logic; -- premier signal venant de arduino + RAZ variable
	signal Nextbyte : std_logic; -- Second signal venant arduino
	signal ByteSent : std_logic;
	
	-- Gestion des erreurs
	signal ArduinoFuckedUp : std_logic;
	signal NextLoadOut : std_logic;
	signal valeurLEDG4 : std_logic;
	signal valeurLEDGfromEncoder : std_logic_vector(7 downto 0);
	signal valeurLEDGdebug : std_logic_vector(7 downto 0);
	signal devNull : std_logic;
	signal devNullVector : std_logic_vector(15 downto 0);
begin

	-- /!\ 
	-- Valable uniquement si encoderNumber == 2
	ArduinoFlowCtrl <= (not ArduinoFlowCtrl1_N, not ArduinoFlowCtrl2_N);
	Encoder_A <= (Encoder1_A, Encoder2_A);
	Encoder_B <= (Encoder1_B, Encoder2_B);
 
	U1 : miniUART 
	PORT MAP ( 
		SysClk   => CLOCK_50, 		--: in  Std_Logic;  -- System Clock
		Reset    => KEY(0), 		--: in  Std_Logic;  -- Reset input
		TxD      => UART_TXD, 		--: out Std_Logic; PIN 4 (GPIO_01)
		DataIn   => "1010111110010110",	--DataToTransmitBuffer,--
		GetFirstByte => NewRequest, -- pour permettre un load
		GetSecondByte => NextByte,
		ByteSent => ByteSent,
		LoadOut  => valeurLEDGdebug(7),
		NextLoadOut  => valeurLEDGdebug(6),--NextLoadOut,	
		FirstLoadOut  => valeurLEDGdebug(5)-- devNull
	);
	
	-- First encoder
	Quadrature_decoder1: Quadrature_decoder
	GENERIC MAP (
		sampling_interval => 21
	)
	PORT MAP (
		readdata => DataToTransmit(1),
		clk => CLOCK_50,
		reset => KEY(0),
		raz => RAZencoder(1),
		A => Encoder_A(1),
		B => Encoder_B(1),
		errorOut => valeurLEDGdebug(0),
		ledOut => valeurLEDGfromEncoder --LEDG -- 
	);
	
	-- Second encoder
	Quadrature_decoder2: Quadrature_decoder
	GENERIC MAP (
		sampling_interval => 21
	)
	PORT MAP (
		readdata => DataToTransmit(2),
		clk => CLOCK_50,
		reset => KEY(0),
		raz => RAZencoder(2),
		A => Encoder_A(2),
		B => Encoder_B(2),
		errorOut => valeurLEDGdebug(1) --devNull
	);

	DataBuffer : process(CLOCK_50, KEY(0))
	variable CurrentState : CommState := Idle; -- encoder's state
	variable CurrentEncoder : integer range 0 to encoderNumber; -- Number of current encoder between 1 and encoderNumber. Not defined => 0.
	variable TimeOut : integer := 0;  
	begin
		if KEY(0) = '0' then
			CurrentState := Idle;
			CurrentEncoder := 0;
			arduinoFuckedUp <= '0';
		elsif Rising_Edge(CLOCK_50) then
			-- interruption toutes les 0.1 secondes (100us) pour éviter un plantage permanent
			if TimeOut <= 5000000 then 
				TimeOut := TimeOut + 1;
			else
				TimeOut := 0;
				CurrentState := Idle;
			end if;
			
			case CurrentState is
				when Idle =>
					TimeOut := 0; -- on reinitialise
					RAZencoder(CurrentEncoder) <= '0';
					NextByte <= '0';
					NewRequest <= '0';
					CurrentEncoder := 0; 
			
--					if ArduinoFlowCtrl(1) = '0' and ArduinoFlowCtrl(2) = '1' then
--						CurrentState := ArduinoEvent1;
--						CurrentEncoder := 1;
--					end if;
					-------------------------------
					if ArduinoFlowCtrl(1) = '0' and  ArduinoFlowCtrl(2) = '1' then
						CurrentState := ArduinoEvent1;
						CurrentEncoder := 1;
					elsif  ArduinoFlowCtrl(2) = '0' and  ArduinoFlowCtrl(1) = '1' then
						CurrentState := ArduinoEvent1;
						CurrentEncoder := 2;
					end if;
					-------------------------------
					-- case ArduinoFlowCtrl is
						-- when ('0', '0') => null; -- IL NE SE PASSE RIEN
						-- when ('1', '0') => 
							-- CurrentState := ArduinoEvent1;
							-- CurrentEncoder := 1;
						-- when ('0', '1') =>
							-- CurrentState := ArduinoEvent1;
							-- CurrentEncoder := 2;
						-- when others => arduinoFuckedUp <= '1';
					-- end case;
				
				when ArduinoEvent1 =>
					if ArduinoFlowCtrl(CurrentEncoder) = '1' then
						CurrentState := PrepareFirstByte;
					end if;
				when PrepareFirstByte => 
					DataToTransmitBuffer <= DataToTransmit(CurrentEncoder);
					NewRequest <= '1';
					CurrentState := SendFirstByte;
				when SendFirstByte =>
					NewRequest <= '0';
					if ByteSent = '1' then
						CurrentState := FirstByteSent;
					end if;
				when FirstByteSent => 
					if ArduinoFlowCtrl(CurrentEncoder) = '0' then
						CurrentState := ArduinoEvent2;
					end if;
				when ArduinoEvent2 => 
					if ArduinoFlowCtrl(CurrentEncoder) = '1' then
						CurrentState := PrepareSecondByte;
					end if;				
				when PrepareSecondByte => 
					NextByte <= '1';
					CurrentState := SendSecondByte;
				-- ici bug aléatoire
				when SendSecondByte => 
					NextByte <= '0';
					if ByteSent = '1' then
						RAZencoder(CurrentEncoder) <= '1';
						CurrentState := Idle;
					end if;
				when others => NULL;
			end case;
		end if;
	end process;
	
	LEDebugManager : process(SW) -- Switch le mode d'affichage des leds
	begin
		if SW(0) = '0' then
			if SW(1) = '0' then
				LEDG <=  DataToTransmit(1)(7 downto 0);
			else
				LEDG <=  DataToTransmit(1)(15 downto 8);
			end if;
		else
			LEDG <= valeurLEDGdebug; --valeurLEDGfromEncoder;-- Pour voir les valeurs de debug
		end if;
	end process;
	
	UART_TXD <= 'Z'; -- signal nul
	valeurLEDGdebug(2) <= arduinoFuckedUp;
	valeurLEDGdebug(4) <= NextByte;--valeurLEDG4;
	--valeurLEDGdebug(3) <= DataToTransmit(1)(0);
	--valeurLEDGdebug(6) <= ArduinoFlowCtrl(1);
end;