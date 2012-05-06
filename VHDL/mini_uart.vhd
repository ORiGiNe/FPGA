--===========================================================================--
--
--  S Y N T H E Z I A B L E    miniUART   C O R E
--
--  www.OpenCores.Org - January 2000
--  This core adheres to the GNU public license  
--
-- Design units   : miniUART core for the OCRP-1
--
-- File name      : miniuart.vhd
--
-- Purpose        : Implements an miniUART device for communication purposes 
--                  between the OR1K processor and the Host computer through
--                  an RS-232 communication protocol.
--                  
-- Library        : uart_lib.vhd
--
-- Dependencies   : IEEE.Std_Logic_1164
--
-- Simulator      : ModelSim PE/PLUS version 4.7b on a Windows95 PC
--===========================================================================--
-------------------------------------------------------------------------------
-- Revision list
-- Version   Author                 Date           Changes
--
-- 0.1      Ovidiu Lupas     15 January 2000       New model
-- 1.0      Ovidiu Lupas     January  2000         Synthesis optimizations
-- 2.0      Ovidiu Lupas     April    2000         Bugs removed - RSBusCtrl
-- 2.1     ORiGiNe            2012          Modifications et nettoyage par ORiGiNe
--          the RSBusCtrl did not process all possible situations
--
--        olupas@opencores.org
-------------------------------------------------------------------------------
-- Description    : The memory consists of a dual-port memory addressed by
--                  two counters (RdCnt & WrCnt). The third counter (StatCnt)
--                  sets the status signals and keeps a track of the data flow.
-------------------------------------------------------------------------------
-- Entity for miniUART Unit - 9600 baudrate                                  --
-------------------------------------------------------------------------------
library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
 
entity miniUART is
  port (
		SysClk   : in  Std_Logic;  -- System Clock
		Reset    : in  Std_Logic;  -- Reset input
		TxD      : out Std_Logic;
		DataIn   : in  Std_Logic_Vector(15 downto 0); -- 
		GetFirstByte : in  Std_Logic; -- depuis arduino, obtenir octet 1
		GetSecondByte : in  Std_Logic; -- depuis arduino, obtenir octet 2
		ByteSent  : out Std_Logic;
		LoadOut   : out  Std_Logic;
		NextLoadOut   : out  Std_Logic;--NextLoadOut   : out  Std_Logic;  -- Load transmit data
		FirstLoadOut   : out  Std_Logic);
end entity; --================== End of entity ==============================--
-------------------------------------------------------------------------------
-- Architecture for miniUART Controller Unit
-------------------------------------------------------------------------------
architecture uart of miniUART is
  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  signal TxData : Std_Logic_Vector(7 downto 0); -- 
  signal EnabTx : Std_Logic;  -- Enable TX unit
  signal Load   : Std_Logic;  -- Load transmit buffer
  signal TransmitLoad : Std_LOGIC;
  signal FirstLoadDone : Std_Logic;  -- Load transmit fist buffer
  signal NextLoad : Std_Logic;  -- Load transmit second buffer
  signal Init1 : Std_logic;
  signal Init2 : Std_logic;
  -----------------------------------------------------------------------------
  -- Baud rate Generator
  -----------------------------------------------------------------------------
  component ClkUnit is
   port (
     SysClk   : in  Std_Logic;  -- System Clock
     EnableTX : out Std_Logic;  -- Control signal
     Reset    : in  Std_Logic); -- Reset input
  end component;
  -----------------------------------------------------------------------------
  -- Transmitter Unit
  -----------------------------------------------------------------------------
  component TxUnit is
  port (
     Clk    : in  Std_Logic;  -- Clock signal
     Reset  : in  Std_Logic;  -- Reset input
     Enable : in  Std_Logic;  -- Enable input
     Load   : in  Std_Logic;  -- Load transmit data
     TxD    : out Std_Logic;  -- RS-232 data output
     TBufE  : out Std_Logic;  -- Tx buffer empty
     DataO  : in  Std_Logic_Vector(7 downto 0));
  end component;
begin
  -----------------------------------------------------------------------------
  -- Instantiation of internal components
  -----------------------------------------------------------------------------
  ClkDiv : ClkUnit PORT MAP ( 
		SysClk   => SysClk, -- System Clock
		EnableTX => EnabTX,  -- Control signal
		Reset    => Reset  -- Reset input
	);
	
	TxDev : TxUnit PORT MAP ( 
     Clk    => SysClk, -- Clock signal
     Reset  => Reset, -- Reset input
     Enable => EnabTX, -- Enable input
     Load   => TransmitLoad,  -- Load transmit data
     TxD    => TxD,  -- RS-232 data output
     TBufE  => ByteSent, -- Tx buffer empty
     DataO  => TxData
	);
  -----------------------------------------------------------------------------
  -- Combinational section
  -----------------------------------------------------------------------------
  process(SysClk, GetFirstByte, GetSecondByte)
  begin
	 if Rising_Edge(SysClk) then
			if Reset = '0' then
				-- reset
				Load <= '0';
				FirstLoadDone <= '0';
				NextLoad <= '0';
				TransmitLoad <= '0';
				Init1 <= '0';
				--Init2 <= '0';
			elsif GetFirstByte = '1' and Init1 = '0' then
				-- bouton de droite : départ
				Init1 <= '1';
			elsif GetFirstByte = '0' and Init1 = '1' then
				Load <= '1';
				FirstLoadDone <= '0';
				Init1 <= '0';
			--elsif GetSecondByte = '1' and Init2 = '0' then
			--	Init2 <= '1';
			--elsif GetSecondByte = '0' and Init2 = '1' then
				NextLoad <= '1';
			--	Init2 <= '0';
			else
				Load <= '0';
				NextLoad <= '0';
			end if;
			
			-- State 0 : init
			if Load = '0' and FirstLoadDone = '0' then
				TxData <= "11000011";
				TransmitLoad <= '0';
			-- State 1 : transmit first byte
			elsif Load = '1' and FirstLoadDone = '0' then
				--TxData <= DataIn(7 downto 0);
				--TransmitLoad <= '1';
				FirstLoadDone <= '1';
			-- State 2 : transmit second byte
			--elsif FirstLoadDone = '1' and NextLoad = '1' then
				TxData <= DataIn(15 downto 8);
				--FirstLoadDone <= '0';
				TransmitLoad <= '1';
			else
				TxData <= "11000011";
				TransmitLoad <= '0';
				FirstLoadDone <= '0';
			end if;
		end if;
  end process;
  
  LoadOut <= TransmitLoad;
  FirstLoadOut <= FirstLoadDone;
  NextLoadOut <= NextLoad; -- GetSecondByte;
end uart; --===================== End of architecture =======================--

