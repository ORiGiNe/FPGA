library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	
entity gestionUART is
	generic(
		encoderNumber: integer := 2 
		-- nombre de codeurs
		-- /!\ Si cette valeur est modifiée, il faut modifier les assignements au debut de l'archi. /!\
	);
	
	port(
	-- Clocks
	CLOCK : in std_logic;          -- 50 MHz
	 
	-- Buttons and switches
	KEY : in std_logic_vector(1 downto 0);         -- Push buttons
	SW : in std_logic_vector(3 downto 0);          -- Switches
	 
	-- LED displays
	LEDG : out std_logic_vector(7 downto 0);       -- Green LEDs
	 
	-- RS-232 interface
	ArduinoFlowCtrl1_N : in std_logic; -- depuis arduino : "envoie l'octet suivant"
	ArduinoFlowCtrl2_N : in std_logic; 

	-- Encoders interface (2 encoders)
	Encoder1_A : in std_logic;
	Encoder1_B : in std_logic;
	Encoder2_A : in std_logic;
	Encoder2_B : in std_logic;
	
	-- Gestion UART
	TX_empty : in std_logic;
	Global_Reset : out std_logic;
	LoadTX : out std_logic;
	TxData : out Std_Logic_Vector(7 downto 0)
	);
end entity;
	
architecture gestion of gestionUART is
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
		errorOut                 : out std_logic
	);
	end component;
	
	
	type CommState is (Idle, ArduinoEvent1, PrepareFirstByte, SendFirstByte, FirstByteSent, ArduinoEvent2, PrepareSecondByte, SendSecondByte, SecondByteSent, resetEncoder); -- description des etats du protocole de communication
	type logicArray is array(1 to encoderNumber) of std_logic;
	type shortArray is array(1 to encoderNumber) of std_logic_vector(15 downto 0);

	signal ArduinoFlowCtrl : logicArray;
	signal Encoder_A : logicArray;
	signal Encoder_B : logicArray;
	signal DataToTransmit : shortArray;
	signal DataToTransmitBuffer : shortArray;
	signal RAZencoder : logicArray; -- RAZ du codeur

	-- Gestion des erreurs
	signal ArduinoFuckedUp : std_logic;
	signal valeurLEDGdebug : std_logic_vector(7 downto 0);
	
	signal devNull : std_logic;
	
	begin
		-- First encoder
	Quadrature_decoder1: Quadrature_decoder
	GENERIC MAP (
		sampling_interval => 21
	)
	PORT MAP (
		readdata => DataToTransmit(1),
		clk => CLOCK,
		reset => KEY(0),
		raz => RAZencoder(1),
		A => Encoder_A(1),
		B => Encoder_B(1),
		errorOut => ArduinoFuckedUp
	);
	
	-- Second encoder
	Quadrature_decoder2: Quadrature_decoder
	GENERIC MAP (
		sampling_interval => 21
	)
	PORT MAP (
		readdata => DataToTransmit(2),
		clk => CLOCK,
		reset => KEY(0),
		raz => RAZencoder(2),
		A => Encoder_A(2),
		B => Encoder_B(2),
		errorOut => devNull--valeurLEDGdebug(1)
	);
	
	Global_Reset <= KEY(0);
	
	-- /!\ 
	-- Valable uniquement si encoderNumber == 2
	ArduinoFlowCtrl <= (not ArduinoFlowCtrl1_N, not ArduinoFlowCtrl2_N);
	Encoder_A <= (Encoder1_A, Encoder2_A);
	Encoder_B <= (Encoder1_B, Encoder2_B);

	protocol : process(CLOCK, KEY(0), DataToTransmit)
	variable CurrentState : CommState := Idle; -- encoder's state
	variable CurrentEncoder : integer range 0 to encoderNumber; -- Number of current encoder between 1 and encoderNumber. Not defined => 0.
	variable TimeOut : integer := 0;
	
	begin
		if KEY(0) = '0' then
			CurrentState := Idle;
			CurrentEncoder := 0;
			arduinoFuckedUp <= '0';	
			valeurLEDGdebug <= "00000000";
		elsif Rising_Edge(CLOCK) then
			-- interruption toutes les 0.002 secondes pour éviter un plantage permanent
			if TimeOut <= 100000 then 
				TimeOut := TimeOut + 1;
			else
				if TX_empty = '0' then
					TimeOut := 0;
					CurrentState := Idle;
				end if;
			end if;
			
			valeurLEDGdebug(7) <= TX_empty;
			DataToTransmitBuffer <= DataToTransmitBuffer;
			TxData <= "10101010";

			case CurrentState is
				when Idle =>
					-- on reinitialise
					TimeOut := 0;
					LoadTX <= '0';
					RAZencoder <= ('0', '0');
					CurrentEncoder := 0;
					TxData <= "11111111";
					
					-- gestion debug
					valeurLEDGdebug <= "00000000";
					--valeurLEDGdebug(0) <= ArduinoFlowCtrl(1); -- debug
					
					if ArduinoFlowCtrl(1) = '1' and  ArduinoFlowCtrl(2) = '0' then
						valeurLEDGdebug(0) <= '1';
						if TX_empty = '1' then -- Le TX est vide
							CurrentState := ArduinoEvent1;
							CurrentEncoder := 1;
						end if;
					elsif  ArduinoFlowCtrl(2) = '1' and  ArduinoFlowCtrl(1) = '0' then
						valeurLEDGdebug(0) <= '1';
						if TX_empty = '1' then -- Le TX est vide
							CurrentState := ArduinoEvent1;
							CurrentEncoder := 2;
						end if;
					end if;
				when ArduinoEvent1 =>
					valeurLEDGdebug(1) <= '1'; -- debug
					if ArduinoFlowCtrl(CurrentEncoder) = '0' then
						CurrentState := PrepareFirstByte;
					end if;
				when PrepareFirstByte => 
					valeurLEDGdebug(2) <= '1'; -- debug
					DataToTransmitBuffer(CurrentEncoder) <= DataToTransmit(CurrentEncoder);
					TxData <= DataToTransmitBuffer(CurrentEncoder)(7 downto 0);
					LoadTX <= '1';
					CurrentState := SendFirstByte;
				when SendFirstByte =>
					TxData <= DataToTransmitBuffer(CurrentEncoder)(7 downto 0);
					if TX_empty = '0' then -- Le TX est busy = envoi en cours
						LoadTX <= '0'; 
						CurrentState := FirstByteSent;
					end if;
				when FirstByteSent => 
					valeurLEDGdebug(3) <= '1'; -- debug
					if TX_empty = '1' and ArduinoFlowCtrl(CurrentEncoder) = '1' then
						--TxData <= "01010101";
						CurrentState := ArduinoEvent2;
					end if;
				when ArduinoEvent2 => 
					valeurLEDGdebug(4) <= '1'; -- debug
					if ArduinoFlowCtrl(CurrentEncoder) = '0' then
						CurrentState := PrepareSecondByte;
					end if;				
				when PrepareSecondByte => 
					valeurLEDGdebug(5) <= '1'; -- debug
					TxData <= DataToTransmitBuffer(CurrentEncoder)(15 downto 8);
					LoadTX <= '1';
					CurrentState := SendSecondByte;
				when SendSecondByte =>
					TxData <= DataToTransmitBuffer(CurrentEncoder)(15 downto 8);
					if TX_empty = '0' then -- Le TX est busy = envoi en cours
						LoadTX <= '0';
						CurrentState := SecondByteSent;
					end if;
				when SecondByteSent =>					
					valeurLEDGdebug(6) <= '1'; -- debug
					if TX_empty = '1' then--and ArduinoFlowCtrl(CurrentEncoder) = '1' then -- Le TX est ok = envoi fini
						-- CurrentState := resetEncoder;
					-- end if;
        -- when resetEncoder =>
          -- if ArduinoFlowCtrl(CurrentEncoder) = '0' then
						RAZencoder(CurrentEncoder) <= '1';
						CurrentState := idle;
					end if;		
				when others => NULL;
			end case;
		end if;
	end process;
	
	LEDebugManager : process(SW, DataToTransmit, valeurLEDGdebug) -- Switch le mode d'affichage des leds
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
	
	--valeurLEDGdebug(2) <= '1';--arduinoFuckedUp;
end gestion;