--
-- Copyright (C) 2004  Mihai Munteanu
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
--
-- You can contact me at:
-- http://www.hp-h.com/p/munte
--

-------------------------------------------------------------------------------
--
--  Simple RS232 UART
--
--
--  OVERVIEW
--  --------
--
--  Clean RTL. Only one clock.
--  Only 8N1 mode supported. 8N2 also appears to work fine
--  Baud rate derived from the main clock
--  Has no FIFO
--  
--  Tested with T80 (Z80 compatible) core on an Spartan 3 Starter Kit board
--
--
--  REGISTERS
--  ---------
-------------------------------------------------------------------------------
--  A0 input    Register
-------------------------------------------------------------------------------
--  0           RX byte - read only
--  0           TX byte - write only
--  1           Status register - read only
--                  bit 0: TX_busy_n    '0' during a byte transmission
--                                      Goes to'1' when byte transmision done
--                                      A new byte cannot be loaded while tx busy
--                  bit 1: RX_full      '1' if a byte had been received
--                                      Cleared by reading the byte
-------------------------------------------------------------------------------
--
--
--  INPUTS/OUTPUTS
--  --------------
--
--  See comments below in the entity
--
--
--  HISTORY
--  -------
--
--  05.11.2004  Mihai Munteanu      First version.
--  16.11.2004  Mihai Munteanu      Added header and comments
--
---------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity our_uart is
    Port (
        Clk     : in std_logic;         -- main clock
        Reset_n : in std_logic;         -- main reset
        TXD     : out std_logic;        -- RS232 TX data

     -- bus interface
        CE_N    : in std_logic;         -- chip enable
        WR_N    : in std_logic;         -- write enable
        D_IN   : in std_logic_vector(7 downto 0);

        -- interrupt signals- same signals as the status register bits
        TX_busy_n   : out std_logic
    );
end our_uart;

architecture RTL of our_uart is

    COMPONENT baud_cnt
	 Generic (
		constant 
			cnt_limit : integer
	 );
    PORT(
        clk 	: IN std_logic;
        reset 	: IN std_logic;
        ck_en 	: OUT std_logic
        );
    END COMPONENT;

    COMPONENT tx
    PORT(
        d_in 	: IN std_logic_vector(7 downto 0);
        load 	: IN std_logic;
        clk 	: IN std_logic;
        ck_en 	: IN std_logic;
        reset 	: IN std_logic;
        tx_out 	: OUT std_logic;
        busy 	: OUT std_logic
        );
    END COMPONENT;

    SIGNAL Reset        :  std_logic;
    SIGNAL tx_busy_sig  :  std_logic;
    SIGNAL ck_en        :  std_logic;
    SIGNAL load_tx      :  std_logic;

begin

Gestion_Emission : process (Clk, WR_N, CE_N, tx_busy_sig, Reset_n)
	begin
	IF Reset_n = '0' then
		load_tx <= '0';
	Elsif (Clk'event and Clk = '1') then
    	load_tx <= ( NOT WR_N ) and ( NOT CE_N ) and (NOT tx_busy_sig);
	End if;
End process Gestion_Emission;
	
    Reset <= NOT Reset_n;
    TX_busy_n   <= NOT tx_busy_sig;

	baud_cnt_u0: baud_cnt 
		GENERIC MAP (
			cnt_limit	=> 145
		)
		PORT MAP(
        clk 		=> Clk,
        reset 		=> Reset,
        ck_en 		=> ck_en
    );

    tx_u0: tx PORT MAP(
        tx_out 	=> TXD,
        d_in 	=> D_IN,
        busy 	=> TX_busy_sig,
        load 	=> load_tx,
        clk 	=> Clk,
        ck_en 	=> ck_en,
        reset 	=> Reset
    );

end RTL;

