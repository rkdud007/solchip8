//! code is credit from https://github.com/aquova/chip8-book/tree/master/code/desktop

use std::env;
use std::fs::File;
use std::io::Read;
use std::str::FromStr;

use alloy::network::{EthereumWallet, Network};
use alloy::node_bindings::Anvil;
use alloy::primitives::{Address, U256};
use alloy::providers::ext::AnvilApi;
use alloy::providers::{Provider, ProviderBuilder};
use alloy::signers::local::PrivateKeySigner;
use alloy::sol;
use alloy::transports::http::reqwest::Url;
use alloy::transports::Transport;
use sdl2::event::Event;
use sdl2::keyboard::Keycode;
use sdl2::pixels::Color;
use sdl2::rect::Rect;
use sdl2::render::Canvas;
use sdl2::video::Window;
use Emu::EmuInstance;

const SCREEN_WIDTH: usize = 64;
const SCREEN_HEIGHT: usize = 32;
const SCALE: u32 = 15;
const WINDOW_WIDTH: u32 = (SCREEN_WIDTH as u32) * SCALE;
const WINDOW_HEIGHT: u32 = (SCREEN_HEIGHT as u32) * SCALE;
const TICKS_PER_FRAME: usize = 5;

sol! {
    #[sol(rpc, bytecode="6080346103a957610a0081016001600160401b038111828210176103955760405260f0815260906020820152609060408201526090606082015260f06080820152602060a0820152606060c0820152602060e08201526020610100820152607061012082015260f0610140820152601061016082015260f061018082015260806101a082015260f06101c082015260f06101e0820152601061020082015260f0610220820152601061024082015260f0610260820152609061028082015260906102a082015260f06102c082015260106102e0820152601061030082015260f0610320820152608061034082015260f0610360820152601061038082015260f06103a082015260f06103c082015260806103e082015260f0610400820152609061042082015260f061044082015260f0610460820152601061048082015260206104a082015260406104c082015260406104e082015260f0610500820152609061052082015260f0610540820152609061056082015260f061058082015260f06105a082015260906105c082015260f06105e0820152601061060082015260f061062082015260f0610640820152609061066082015260f061068082015260906106a082015260906106c082015260e06106e0820152609061070082015260e0610720820152609061074082015260e061076082015260f061078082015260806107a082015260806107c082015260806107e082015260f061080082015260e061082082015260906108408201526090610860820152609061088082015260e06108a082015260f06108c082015260806108e082015260f0610900820152608061092082015260f061094082015260f0610960820152608061098082015260f06109a082015260806109c082015260806109e08201525f5b6002811061035757505f905f5b60108110610329578260025561020061ffff1960035416176003555f5b605081101561031a578060051c908154611000821015610306576004909201805460019360ff600385901b60f81681811b1990931691831c1690911b179055016102c1565b634e487b7160e01b5f52603260045260245ffd5b604051611cb690816103ae8239f35b9091602061034e6001928460ff875116919060ff809160031b9316831b921b19161790565b930191016102a4565b5f5f5b6020811061036d57508155600101610297565b835160019492859160209160ff600386901b81811b199092169216901b17930194500161035a565b634e487b7160e01b5f52604160045260245ffd5b5f80fdfe60806040526004361015610011575f80fd5b5f3560e01c8063074b6fac14610adf5780632f57e5f714610aa95780633eaf5d9f14610a8e5780636398efc814610a6657806366050ab914610a3957806368ad83f114610a155780637ef91424146107c057806380bc398e146107605780638153da03146105cf578063825284fd146105985780638c41bd001461056657806392ddeea014610517578063997a40c0146104c45780639cba24bb146104a0578063a560ea3b14610474578063a72b660414610437578063a8b3ac7814610417578063a95c372d146103f1578063ae344f8e146103ce578063c040622614610345578063cbc95019146102c9578063d19dc8b5146102a8578063d2bf2e1c1461027d578063d826f88f146101515763e781d8c51461012c575f80fd5b3461014d575f36600319011261014d57602061ffff60035416604051908152f35b5f80fd5b3461014d575f36600319011261014d576003805461ffff19166102001790556108005f5b81811061025e575f5b6010811061023f5763ffffffff1960c5541660c5555f5b6010811061021f575f5b601081106102005761ffff1960c8541660c8555f5b60508110156101fe576001908060051c546101f660ff6101d384610c19565b91909360f88660031b161c169083549060ff809160031b9316831b921b19161790565b9055016101b4565b005b8061020c600192610d16565b60ff82549160031b1b191690550161019f565b8061022b600192610c97565b61ffff82549160031b1b1916905501610195565b8061024b600192610cfe565b60ff82549160031b1b191690550161017e565b8061026a600192610c32565b60ff82549160031b1b1916905501610175565b3461014d57602036600319011261014d5760ff610298610bab565b1660ff1960c854161760c8555f80f35b3461014d575f36600319011261014d57602061ffff60c55416604051908152f35b3461014d576102d736610b5a565b90601081101561030c576102ed61030891610d16565b909215159083549060ff809160031b9316831b921b19161790565b9055005b60405162461bcd60e51b8152602060048201526011602482015270092dcecc2d8d2c840d6caf240d2dcc8caf607b1b6044820152606490fd5b3461014d575f36600319011261014d5760c95415610395575f5b60c9548110156101fe5760019061037f61ffff60035416610fff11610da4565b61038f61038a610df0565b610eba565b0161035f565b60405162461bcd60e51b8152602060048201526011602482015270050726f6772616d2073697a65206973203607c1b6044820152606490fd5b3461014d575f36600319011261014d57602060ff60c85460081c16604051908152f35b3461014d575f36600319011261014d57602061040b610df0565b61ffff60405191168152f35b3461014d575f36600319011261014d57602060ff60c85416604051908152f35b3461014d57602036600319011261014d57602061ffff61046460043561045f60108210610c4b565b610c97565b90549060031b1c16604051908152f35b3461014d57602036600319011261014d57602060ff61046460043561049b60108210610cb2565b610cfe565b3461014d575f36600319011261014d5760206104ba610d2e565b6040519015158152f35b3461014d57604036600319011261014d576104dd610bab565b61030860ff6104fc6104ed610b9b565b9361049b601084831610610cb2565b919093169083549060ff809160031b9316831b921b19161790565b3461014d57604036600319011261014d5760043560243561ffff8116810361014d5761054c8261045f60106101fe9510610c4b565b90919061ffff8084549260031b9316831b921b1916179055565b3461014d57602036600319011261014d5761057f610bab565b61ff0060c8549160081b169061ff0019161760c8555f80f35b3461014d57604036600319011261014d5760043561030860ff6104fc6105bc610b9b565b936105ca6110008210610bcd565b610c19565b3461014d57602036600319011261014d5760043567ffffffffffffffff811161014d573660238201121561014d5780600401359067ffffffffffffffff821161074c578160051b90604051926106286020840185610b79565b8352602460208401928201019036821161014d57602401915b818310610732578380516102000180610200116106d95761100081116106ed576102005b81811061067357825160c955005b6101ff198101908082116106d95783518210156106c55760ff602060019360051b86010151166106bd6106a583610c19565b819391549060ff809160031b9316831b921b19161790565b905501610665565b634e487b7160e01b5f52603260045260245ffd5b634e487b7160e01b5f52601160045260245ffd5b60405162461bcd60e51b815260206004820152601c60248201527f4461746120746f6f206c6172676520746f2066697420696e2052414d000000006044820152606490fd5b823560ff8116810361014d57815260209283019201610641565b634e487b7160e01b5f52604160045260245ffd5b3461014d5761076e36610b5a565b90610800811015610785576102ed61030891610c32565b60405162461bcd60e51b8152602060048201526013602482015272496e646578206f7574206f6620626f756e647360681b6044820152606490fd5b3461014d575f36600319011261014d5762010000806040516107e28282610b79565b36903760405160845f825b610800601f830110610833575050506108068282610b79565b604051905f825b610800821061081b57505050f35b6020806001928551151581520193019101909161080d565b6001610400602092855460ff81161515825260ff8160081c1615158583015260ff8160101c161515604083015260ff8160181c161515606083015260ff81861c161515608083015260ff8160281c16151560a083015260ff8160301c16151560c083015260ff8160381c16151560e083015260ff8160401c16151561010083015260ff8160481c16151561012083015260ff8160501c16151561014083015260ff8160581c16151561016083015260ff8160601c16151561018083015260ff8160681c1615156101a083015260ff8160701c1615156101c083015260ff8160781c1615156101e083015260ff8160801c16151561020083015260ff8160881c16151561022083015260ff8160901c16151561024083015260ff8160981c16151561026083015260ff8160a01c16151561028083015260ff8160a81c1615156102a083015260ff8160b01c1615156102c083015260ff8160b81c1615156102e083015260ff8160c01c16151561030083015260ff8160c81c16151561032083015260ff8160d01c16151561034083015260ff8160d81c16151561036083015260ff8160e01c16151561038083015260ff8160e81c1615156103a083015260ff8160f01c1615156103c083015260f81c15156103e0820152019301910190916107ed565b3461014d575f36600319011261014d57602061ffff60c55460101c16604051908152f35b3461014d57602036600319011261014d5761ffff610a55610b49565b1661ffff1960c554161760c5555f80f35b3461014d57602036600319011261014d57602060ff6104646004356105ca6110008210610bcd565b3461014d575f36600319011261014d576101fe61038a610df0565b3461014d57602036600319011261014d57610ac2610b49565b63ffff000060c5549160101b169063ffff000019161760c5555f80f35b3461014d575f36600319011261014d5760c85460ff811680610b2d575b505060c85460ff8160081c1680610b0f57005b610b1b61ff0091610bbb565b60081b169061ff0019161760c8555f80f35b610b3860ff91610bbb565b169060ff19161760c8558080610afc565b6004359061ffff8216820361014d57565b604090600319011261014d5760043590602435801515810361014d5790565b90601f8019910116810190811067ffffffffffffffff82111761074c57604052565b6024359060ff8216820361014d57565b6004359060ff8216820361014d57565b60ff5f199116019060ff82116106d957565b15610bd457565b60405162461bcd60e51b815260206004820152601760248201527f52414d20696e646578206f7574206f6620626f756e64730000000000000000006044820152606490fd5b906110008210156106c557601f8260051c600401921690565b906108008210156106c557601f8260051c608401921690565b15610c5257565b60405162461bcd60e51b815260206004820152601960248201527f537461636b20696e646578206f7574206f6620626f756e6473000000000000006044820152606490fd5b9060108210156106c557601e8260041c60c6019260011b1690565b15610cb957565b60405162461bcd60e51b815260206004820152601e60248201527f5620726567697374657220696e646578206f7574206f6620626f756e647300006044820152606490fd5b9060108210156106c557601f8260051c60c401921690565b9060108210156106c557601f8260051c60c701921690565b6108005f5b818110610d41575050600190565b60ff610d4c82610c32565b90549060031b1c16610d6057600101610d33565b50505f90565b61ffff60019116019061ffff82116106d957565b61ffff60029116019061ffff82116106d957565b9061ffff8091169116019061ffff82116106d957565b15610dab57565b60405162461bcd60e51b815260206004820152601d60248201527f50726f6772616d20636f756e746572206f7574206f6620626f756e64730000006044820152606490fd5b60035461ff0061ffff821691610e1561100061ffff610e0e86610d66565b1610610da4565b610e1e83610c19565b90549060031b1c9061ffff610e4860ff610e3a6105ca88610d66565b90549060031b1c1695610d7a565b169061ffff19161760035560081b161790565b60ff1660ff81146106d95760010190565b15610e7357565b60405162461bcd60e51b815260206004820152600b60248201526a496e76616c6964206b657960a81b6044820152606490fd5b9060ff8091169116019060ff82116106d957565b61ffff811615611c7d57600f81600c1c16600f8260081c1690600f8360041c1690600f8416908015808091611c75575b80611c6b575b80611c63575b15610f32575061080094505f93505050505b818110610f13575050565b80610f1f600192610c32565b60ff82549160031b1b1916905501610f08565b80611c5b575b80611c51575b80611c47575b15610fe157505050505060c55461ffff8160101c168015610faa575f19019061ffff82116106d95761ffff610f949163ffff0000829460101b169063ffff00001916178060c55560101c16610c97565b90549060031b1c1661ffff196003541617600355565b60405162461bcd60e51b815260206004820152600f60248201526e537461636b20756e646572666c6f7760881b6044820152606490fd5b60018103610fff5750505050610fff1661ffff196003541617600355565b600281036110a3575050505061ffff600354169061ffff60c55460101c16601081101561106d57610fff9261054c61103692610c97565b60c55463ffff000061104e61ffff8360101c16610d66565b60101b169063ffff000019161760c5551661ffff196003541617600355565b60405162461bcd60e51b815260206004820152600e60248201526d537461636b206f766572666c6f7760901b6044820152606490fd5b600381036110eb5750505060ff6110ba8192610cfe565b9190931692549060031b1c16146110cd57565b60035461ffff6110de818316610d7a565b169061ffff191617600355565b600481036111155750505060ff6111028192610cfe565b9190931692549060031b1c16036110cd57565b6005819593951480611c3f575b156111565750505061114760ff6111398193610cfe565b90549060031b1c1692610cfe565b90549060031b1c16146110cd57565b919391600681036111765750505060ff6104fc61117292610cfe565b9055565b600781036111bc5750505061118d61117291610cfe565b60ff6111a68184969454941682858560031b1c16610ea6565b16919060ff809160031b9316831b921b19161790565b919391600881148080611c37575b156111e55750505050906106a560ff61113961117293610cfe565b8080611c2d575b1561122b57505050509061120760ff61113961117293610cfe565b819391549160ff838360031b1c1617919060ff809160031b9316831b921b19161790565b8080611c23575b1561127957505050509061125861124b61117292610cfe565b90549060031b1c92610cfe565b8154919360ff60039290921b82811b19841693811c909116909116901b1790565b8080611c19575b156112be57505050509061129b60ff61113961117293610cfe565b8154919360ff60039290921b82811b19841693811c8316909118909116901b1790565b8080611c0f575b1561133957505050509060ff6104fc6112f761117293836112e98161113989610cfe565b90549060031b1c1690610d8e565b938261ffff8616115f1461132f576113278360015b60c454911660781b60ff60781b1660ff60781b199091161790565b60c455610cfe565b611327835f61130c565b8080611c05575b156113c257505050509061139c60ff611139611172938261136087610cfe565b90549060031b1c168361137283610cfe565b905460039190911b1c161161132f5760c45460ff60781b1916607884901b600160781b1617611327565b60ff829492549281848460031b1c160316919060ff809160031b9316831b921b19161790565b8080611bfb575b15611435575050505061117291508061132760016113e961140f94610cfe565b905460c45460039290921b1c9190911660781b60ff60781b1660ff60781b199091161790565b8192915490607f828260031b1c60011c16919060ff809160031b9316831b921b19161790565b8080611bf1575b156114925750505050906106a560ff8061146f848261145d61117297610cfe565b90549060031b1c168361137289610cfe565b90549060031b1c168161148186610cfe565b90549060031b1c1690031692610cfe565b80611be7575b156115065750505061117291508061132760016114b76114e094610cfe565b905460c45460039290921b1c60071c9190911660781b60ff60781b1660ff60781b199091161790565b819291549060fe828260031b1c60011b16919060ff809160031b9316831b921b19161790565b6009811480611bdf575b156115365750505061152760ff6111398193610cfe565b90549060031b1c16036110cd57565b600a819592939495145f1461155c57505050610fff91501661ffff1960c554161760c555565b600b810361158e5750505061ffff9150610fff61157f911660ff60c45416610d8e565b1661ffff196003541617600355565b600c81036115ee575050505f194301904382116106d95760ff6106a5916111729360035460405190602082019242845240604083015261ffff60f01b9060f01b166060820152604281526115e3606282610b79565b519020161692610cfe565b919390925090600d81036117465750611610603f611139601f93969596610cfe565b90549060031b1c169160c492600f90845460ff600f60031b1b191685555f925b60ff84168781101561173c576116516105ca60ff9261ffff60c55416610d8e565b90549060031b1c16965f5b60ff81166008811015611729576007039060ff82116106d957603f611681828a610ea6565b16623fffc06107c06116938a89610ea6565b60061b1616019063ffffffff82116106d95760ff926117016116e78d60018063ffffffff8198169289806116c686610c32565b90549060031b1c1697161c1614841515149380611722575b61170a57610c32565b9092159083549060ff809160031b9316831b921b19161790565b9055011661165c565b8d80548c60031b908989831b921b1916179055610c32565b50836116de565b5090975050600190930160ff1692611630565b5095505050505050565b90939290600e81148080611bd5575b80611bcb575b1561179b57505050509061178d60ff6117748193610cfe565b90549060031b1c1661178860108210610e6c565b610d16565b90549060031b1c166110cd57565b80611bc1575b80611bb7575b156117ce57505050906117bf60ff6117748193610cfe565b90549060031b1c16156110cd57565b600f14918280611baf575b80611ba5575b156117fa57505050906111726106a560ff60c8541692610cfe565b8280611b9d575b80611b93575b1561188e575050505f5f5b60ff811660108110156118845760ff61182a83610d16565b90549060031b1c16611842575060010160ff16611812565b929361185392506106a59150610cfe565b905560015b1561185f57565b60035460011961ffff82160161ffff81116106d95761ffff169061ffff191617600355565b5050909150611858565b8280611b89575b80611b7f575b156118c457505050906118af60ff91610cfe565b90549060031b1c1660ff1960c854161760c855565b8280611b75575b80611b6b575b1561190157505050906118e390610cfe565b90549060031b1c61ff0060c8549160081b169061ff0019161760c855565b8280611b61575b80611b57575b15611949575050509061192260ff91610cfe565b90549060031b1c1661ffff61193c60c55492828416610d8e565b169061ffff19161760c555565b8280611b4d575b80611b43575b1561198f575050509060ff61196c600592610cfe565b90549060031b1c160261ffff81169081036106d95761ffff1960c554161760c555565b8280611b39575b80611b2f575b15611a0d575050509060ff6119b2600a92610cfe565b90549060031b1c16606481046119d260ff6104fc61ffff60c55416610c19565b90558160ff81830416066119f360ff6104fc6105ca61ffff60c55416610d66565b90550661117260ff6104fc6105ca61ffff60c55416610d7a565b8280611b25575b80611b1b575b15611a6f57505050905f5b60ff811690828211611a6a57611a6591611a5e6106a56105ca60ff611a4986610cfe565b90549060031b1c169361ffff60c55416610d8e565b9055610e5b565b611a25565b505050565b82611b10575b5081611b05575b5015611ac7575f5b60ff8116838111611ac1579060ff611aa86105ca611abc9461ffff60c55416610d8e565b90549060031b1c16611a5e6106a583610cfe565b611a84565b50509050565b60405162461bcd60e51b815260206004820152601660248201527513dc18dbd919481b9bdd081a5b5c1b195b595b9d195960521b6044820152606490fd5b60059150145f611a7c565b60061491505f611a75565b5060058214611a1a565b5060058114611a14565b506003821461199c565b5060038114611996565b5060098214611956565b5060028114611950565b50600e821461190e565b5060018114611908565b50600882146118d1565b50600181146118cb565b506005821461189b565b5060018114611895565b50600a8214611807565b508015611801565b50600782146117df565b5080156117d9565b50600182146117a7565b50600a83146117a1565b50600e831461175b565b5060098414611755565b508115611510565b50600e8214611498565b506007831461143c565b50600683146113c9565b5060058314611340565b50600483146112c5565b5060038314611280565b5060028314611232565b50600183146111ec565b5082156111ca565b508115611122565b50600e8214610f44565b50600e8314610f3e565b508315610f38565b508215610ef6565b50600e8414610ef0565b508415610eea565b5056fea264697066735822122066f40ade668cb258b491bfecda9f63a94fe531bb3d1459a4d8ae6e719e787bf464736f6c634300081c0033")]
    contract Emu {
        // -------------------------------------------------------------------------
        // Constants
        // -------------------------------------------------------------------------

        /// @notice screen width 64 pixels
        uint16 constant SCREEN_WIDTH = 64;
        /// @notice screen height 32 pixels
        uint16 constant SCREEN_HEIGHT = 32;

        /// @notice size of RAM
        uint16 constant RAM_SIZE = 4096;
        /// @notice number of registers
        uint8 constant NUM_REGS = 16;
        /// @notice number of stack entries
        uint8 constant STACK_SIZE = 16;
        /// @notice number of keys
        uint8 constant NUM_KEYS = 16;

        // -------------------------------------------------------------------------
        // Display
        // -------------------------------------------------------------------------


        /// @notice fontset
        /// @dev Most modern emulators will use that space to store the sprite data for font characters of all the
        /// hexadecimal digits, that is characters of 0-9 and A-F. We could store this data at any fixed position in RAM, but this
        /// space is already defined as empty anyway. Each character is made up of eight rows of five pixels, with each row using
        /// a byte of data, meaning that each letter altogether takes up five bytes of data. The following diagram illustrates how
        /// a character is stored as bytes
        uint8[80] FONTSET = [
            0xF0,
            0x90,
            0x90,
            0x90,
            0xF0, // 0
            0x20,
            0x60,
            0x20,
            0x20,
            0x70, // 1
            0xF0,
            0x10,
            0xF0,
            0x80,
            0xF0, // 2
            0xF0,
            0x10,
            0xF0,
            0x10,
            0xF0, // 3
            0x90,
            0x90,
            0xF0,
            0x10,
            0x10, // 4
            0xF0,
            0x80,
            0xF0,
            0x10,
            0xF0, // 5
            0xF0,
            0x80,
            0xF0,
            0x90,
            0xF0, // 6
            0xF0,
            0x10,
            0x20,
            0x40,
            0x40, // 7
            0xF0,
            0x90,
            0xF0,
            0x90,
            0xF0, // 8
            0xF0,
            0x90,
            0xF0,
            0x10,
            0xF0, // 9
            0xF0,
            0x90,
            0xF0,
            0x90,
            0x90, // A
            0xE0,
            0x90,
            0xE0,
            0x90,
            0xE0, // B
            0xF0,
            0x80,
            0x80,
            0x80,
            0xF0, // C
            0xE0,
            0x90,
            0x90,
            0x90,
            0xE0, // D
            0xF0,
            0x80,
            0xF0,
            0x80,
            0xF0, // E
            0xF0,
            0x80,
            0xF0,
            0x80,
            0x80 // F
        ];

        struct Emulator {
            /// @notice 16-bit program counter
            uint16 pc;
            /// @notice 4KB RAM
            uint8[4096] ram;
            /// @notice A 64x32 monochrome display
            bool[2048] screen;
            /// @notice Sixteen 8-bit general purpose registers, referred to as V0 thru VF
            uint8[16] v_reg;
            /// @notice Single 16-bit register used as a pointer for memory access, called the I Register
            uint16 i_reg;
            /// @notice Stack pointer
            uint16 sp;
            /// @notice 16-bit stack used for calling and returning from subroutines
            uint16[16] stack;
            /// @notice 16-key keyboard input
            bool[16] keys;
            /// @notice Delay timer
            uint8 dt;
            /// @notice Sound timer
            uint8 st;
            /// @notice Program size
            uint256 program_size;
        }

        Emulator emu;

        // -------------------------------------------------------------------------
        // Initialization
        // -------------------------------------------------------------------------

        /// @notice start address for program (usually 0x200)
        uint16 constant START_ADDR = 0x200;

        constructor() {
            emu.pc = START_ADDR;
            for (uint256 i = 0; i < FONTSET_SIZE; i++) {
                emu.ram[i] = FONTSET[i];
            }
        }

        /// @notice Reset the emulator
        function reset() public {
            emu.pc = START_ADDR;
            for (uint256 i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) {
                emu.screen[i] = false;
            }
            for (uint256 i = 0; i < NUM_REGS; i++) {
                emu.v_reg[i] = 0;
            }
            emu.i_reg = 0;
            emu.sp = 0;
            for (uint256 i = 0; i < STACK_SIZE; i++) {
                emu.stack[i] = 0;
            }
            for (uint256 i = 0; i < NUM_KEYS; i++) {
                emu.keys[i] = false;
            }
            emu.dt = 0;
            emu.st = 0;
            // Copy FONTSET
            for (uint256 i = 0; i < FONTSET_SIZE; i++) {
                emu.ram[i] = FONTSET[i];
            }
        }

        // -------------------------------------------------------------------------
        // Emulation functions
        // -------------------------------------------------------------------------

        /// @notice Push a value onto the stack
        function push(uint16 val) internal {
            require(emu.sp < STACK_SIZE, "Stack overflow");
            emu.stack[emu.sp] = val;
            emu.sp += 1;
        }

        /// @notice Pop a value from the stack
        function pop() internal returns (uint16) {
            require(emu.sp > 0, "Stack underflow");
            emu.sp -= 1;
            return emu.stack[emu.sp];
        }

        /// @notice CPU processing loop
        /// @dev This function is called once per tick of the CPU.
        /// Fetch the next instruction, decode and execute it.
        function tick() public {
            // Fetch
            uint16 op = fetch();
            // Decode & execute
            execute(op);
        }

        function tickTimers() public {
            if (emu.dt > 0) {
                emu.dt -= 1;
            }

            if (emu.st > 0) {
                if (emu.st == 1) {
                    // BEEP
                }
                emu.st -= 1;
            }
        }

        /// @notice Fetch the next instruction
        function fetch() public returns (uint16) {
            require(emu.pc + 1 < RAM_SIZE, "Program counter out of bounds");
            uint16 higher_byte = uint16(emu.ram[emu.pc]);
            uint16 lower_byte = uint16(emu.ram[emu.pc + 1]);
            uint16 op = (higher_byte << 8) | lower_byte;
            emu.pc += 2;
            return op;
        }

        function run() public {
            require(emu.program_size > 0, "Program size is 0");
            for (uint256 i = 0; i < emu.program_size; i++) {
                require(emu.pc < RAM_SIZE - 1, "Program counter out of bounds");
                // Fetch the opcode
                uint16 op = fetch();
                // Execute the opcode
                execute(op);
            }
        }

        function execute(uint16 op) internal {
            // 0000 - Nop - NOP
            if (op == 0x0000) return;

            uint8 digit1 = uint8((op & 0xF000) >> 12);
            uint8 digit2 = uint8((op & 0x0F00) >> 8);
            uint8 digit3 = uint8((op & 0x00F0) >> 4);
            uint8 digit4 = uint8(op & 0x000F);

            //  00E0 - CLS
            if (digit1 == 0x0 && digit2 == 0x0 && digit3 == 0xE && digit4 == 0) {
                for (uint256 i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) {
                    emu.screen[i] = false;
                }
                return;
            }
            // 00EE - RET
            else if (digit1 == 0x0 && digit2 == 0x0 && digit3 == 0xE && digit4 == 0xE) {
                emu.pc = pop();
                return;
            }
            //  1NNN - JMP NNN
            else if (digit1 == 0x1) {
                uint16 nnn = op & 0x0FFF;
                emu.pc = nnn;
                return;
            }
            //  2NNN - CALL NNN
            else if (digit1 == 0x2) {
                uint16 nnn = op & 0x0FFF;
                push(emu.pc);
                emu.pc = nnn;
                return;
            }
            //  3NNN - SKIP VX == NN
            else if (digit1 == 0x3) {
                uint8 nn = uint8(op & 0xFF);
                if (emu.v_reg[digit2] == nn) {
                    emu.pc += 2;
                }
                return;
            }
            //  4NNN - SKIP VX != NN
            else if (digit1 == 0x4) {
                uint8 nn = uint8(op & 0xFF);
                if (emu.v_reg[digit2] != nn) {
                    emu.pc += 2;
                }
                return;
            }
            //  5NNN - SKIP VX == VY
            else if (digit1 == 0x5 && digit4 == 0x0) {
                if (emu.v_reg[digit2] == emu.v_reg[digit3]) {
                    emu.pc += 2;
                }
                return;
            }
            //  6NNN - VX = NN
            else if (digit1 == 0x6) {
                uint8 nn = uint8(op & 0xFF);
                emu.v_reg[digit2] = nn;
                return;
            }
            //  7NNN - VX += NN
            else if (digit1 == 0x7) {
                uint8 nn = uint8(op & 0xFF);
                emu.v_reg[digit2] += nn;
                return;
            }
            // 8XY0 - VX = VY
            else if (digit1 == 0x8 && digit4 == 0x0) {
                emu.v_reg[digit2] = emu.v_reg[digit3];
                return;
            }
            // 8XY1 - VX |= VY
            else if (digit1 == 0x8 && digit4 == 0x1) {
                emu.v_reg[digit2] |= emu.v_reg[digit3];
                return;
            }
            // 8XY2 - VX &= VY
            else if (digit1 == 0x8 && digit4 == 0x2) {
                emu.v_reg[digit2] &= emu.v_reg[digit3];
                return;
            }
            // 8XY3 - VX ^= VY
            else if (digit1 == 0x8 && digit4 == 0x3) {
                emu.v_reg[digit2] ^= emu.v_reg[digit3];
                return;
            }
            // 8XY4 - VX += VY (with carry)
            else if (digit1 == 0x8 && digit4 == 0x4) {
                uint8 x = digit2;
                uint8 y = digit3;
                uint16 sum = uint16(emu.v_reg[x]) + uint16(emu.v_reg[y]);
                emu.v_reg[0xF] = sum > 0xFF ? 1 : 0;
                emu.v_reg[x] = uint8(sum);
                return;
            }
            // 8XY5 - VX -= VY (with borrow)
            else if (digit1 == 0x8 && digit4 == 0x5) {
                uint8 x = digit2;
                uint8 y = digit3;
                emu.v_reg[0xF] = emu.v_reg[x] >= emu.v_reg[y] ? 1 : 0;
                unchecked {
                    emu.v_reg[x] -= emu.v_reg[y];
                }
                return;
            }
            // 8XY6 - VX >>= 1
            else if (digit1 == 0x8 && digit4 == 0x6) {
                uint8 x = digit2;
                emu.v_reg[0xF] = emu.v_reg[x] & 0x1;
                emu.v_reg[x] >>= 1;
                return;
            }
            // 8XY7 - VX = VY - VX (with borrow)
            else if (digit1 == 0x8 && digit4 == 0x7) {
                uint8 x = digit2;
                uint8 y = digit3;
                emu.v_reg[0xF] = emu.v_reg[y] >= emu.v_reg[x] ? 1 : 0;
                unchecked {
                    emu.v_reg[x] = emu.v_reg[y] - emu.v_reg[x];
                }
                return;
            }
            // 8XYE - VX <<= 1
            else if (digit1 == 0x8 && digit4 == 0xE) {
                uint8 x = digit2;
                emu.v_reg[0xF] = (emu.v_reg[x] >> 7) & 0x1;
                emu.v_reg[x] <<= 1;
                return;
            }
            // 9XY0 - SKIP VX != VY
            else if (digit1 == 0x9 && digit4 == 0x0) {
                uint8 x = digit2;
                uint8 y = digit3;
                if (emu.v_reg[x] != emu.v_reg[y]) {
                    emu.pc += 2;
                }
                return;
            }
            // ANNN - I = NNN
            else if (digit1 == 0xA) {
                uint16 nnn = op & 0x0FFF;
                emu.i_reg = nnn;
                return;
            }
            // BNNN - PC = V0 + NNN
            else if (digit1 == 0xB) {
                uint16 nnn = op & 0x0FFF;
                emu.pc = uint16(emu.v_reg[0]) + nnn;
                return;
            }
            // CXNN - VX = rand() & NN
            else if (digit1 == 0xC) {
                uint8 x = digit2;
                uint8 nn = uint8(op & 0x00FF);
                // Pseudo-random number generation (not secure)
                uint8 rand =
                    uint8(uint256(keccak256(abi.encodePacked(block.timestamp, blockhash(block.number - 1), emu.pc))) % 256);
                emu.v_reg[x] = rand & nn;
                return;
            }
            // DXYN - DRAW
            else if (digit1 == 0xD) {
                uint8 x = emu.v_reg[digit2] % uint8(SCREEN_WIDTH);
                uint8 y = emu.v_reg[digit3] % uint8(SCREEN_HEIGHT);
                uint8 height = digit4;
                emu.v_reg[0xF] = 0; // Reset VF

                for (uint8 row = 0; row < height; row++) {
                    uint8 sprite_byte = emu.ram[emu.i_reg + row];
                    for (uint8 col = 0; col < 8; col++) {
                        uint8 sprite_pixel = (sprite_byte >> (7 - col)) & 0x1;
                        uint32 screen_x = uint32((x + col) % SCREEN_WIDTH);
                        uint32 screen_y = uint32((y + row) % SCREEN_HEIGHT);
                        uint256 index = screen_y * SCREEN_WIDTH + screen_x;

                        bool pixel_before = emu.screen[index];
                        bool new_pixel = pixel_before != (sprite_pixel == 1);
                        if (pixel_before && !new_pixel) {
                            emu.v_reg[0xF] = 1;
                        }
                        emu.screen[index] = new_pixel;
                    }
                }
                return;
            }
            // EX9E - SKIP if key[VX] pressed
            else if (digit1 == 0xE && digit3 == 0x9 && digit4 == 0xE) {
                uint8 x = digit2;
                uint8 key = emu.v_reg[x];
                require(key < NUM_KEYS, "Invalid key");
                if (emu.keys[key]) {
                    emu.pc += 2;
                }
                return;
            }
            // EXA1 - SKIP if key[VX] not pressed
            else if (digit1 == 0xE && digit3 == 0xA && digit4 == 0x1) {
                uint8 x = digit2;
                uint8 key = emu.v_reg[x];
                require(key < NUM_KEYS, "Invalid key");
                if (!emu.keys[key]) {
                    emu.pc += 2;
                }
                return;
            }
            // FX07 - VX = DT
            else if (digit1 == 0xF && digit3 == 0x0 && digit4 == 0x7) {
                uint8 x = digit2;
                emu.v_reg[x] = emu.dt;
                return;
            }
            // FX0A - Wait for key press
            else if (digit1 == 0xF && digit3 == 0x0 && digit4 == 0xA) {
                uint8 x = digit2;
                bool key_pressed = false;
                for (uint8 i = 0; i < NUM_KEYS; i++) {
                    if (emu.keys[i]) {
                        emu.v_reg[x] = i;
                        key_pressed = true;
                        break;
                    }
                }
                if (!key_pressed) {
                    // Repeat this opcode
                    emu.pc -= 2;
                }
                return;
            }
            // FX15 - DT = VX
            else if (digit1 == 0xF && digit3 == 0x1 && digit4 == 0x5) {
                uint8 x = digit2;
                emu.dt = emu.v_reg[x];
                return;
            }
            // FX18 - ST = VX
            else if (digit1 == 0xF && digit3 == 0x1 && digit4 == 0x8) {
                uint8 x = digit2;
                emu.st = emu.v_reg[x];
                return;
            }
            // FX1E - I += VX
            else if (digit1 == 0xF && digit3 == 0x1 && digit4 == 0xE) {
                uint8 x = digit2;
                emu.i_reg += uint16(emu.v_reg[x]);
                return;
            }
            // FX29 - I = location of sprite for digit VX
            else if (digit1 == 0xF && digit3 == 0x2 && digit4 == 0x9) {
                uint8 x = digit2;
                uint8 digit = emu.v_reg[x];
                emu.i_reg = uint16(digit) * 5; // Each sprite is 5 bytes
                return;
            }
            // FX33 - Store BCD representation of VX in memory locations I, I+1, and I+2
            else if (digit1 == 0xF && digit3 == 0x3 && digit4 == 0x3) {
                uint8 x = digit2;
                uint8 value = emu.v_reg[x];
                emu.ram[emu.i_reg] = value / 100;
                emu.ram[emu.i_reg + 1] = (value / 10) % 10;
                emu.ram[emu.i_reg + 2] = value % 10;
                return;
            }
            // FX55 - Store V0 to VX in memory starting at address I
            else if (digit1 == 0xF && digit3 == 0x5 && digit4 == 0x5) {
                uint8 x = digit2;
                for (uint8 i = 0; i <= x; i++) {
                    emu.ram[emu.i_reg + i] = emu.v_reg[i];
                }
                return;
            }
            // FX65 - Read V0 to VX from memory starting at address I
            else if (digit1 == 0xF && digit3 == 0x6 && digit4 == 0x5) {
                uint8 x = digit2;
                for (uint8 i = 0; i <= x; i++) {
                    emu.v_reg[i] = emu.ram[emu.i_reg + i];
                }
                return;
            } else {
                revert("Opcode not implemented");
            }
        }

        // -------------------------------------------------------------------------
        // Frontend functions
        // -------------------------------------------------------------------------

        /// @notice Get display
        #[derive(Debug, PartialEq, Eq)]
        function getDisplay() public view returns (bool[2048] memory) {
            return emu.screen;
        }

        /// @notice Handle keypress event
        function keypress(uint256 idx, bool pressed) public {
            require(idx < NUM_KEYS, "Invalid key index");
            emu.keys[idx] = pressed;
        }

        /// @notice Load program into memory
        function load(uint8[] memory data) public {
            uint256 start = START_ADDR;
            uint256 end = START_ADDR + data.length;
            require(end <= RAM_SIZE, "Data too large to fit in RAM");
            for (uint256 i = start; i < end; i++) {
                emu.ram[i] = data[i - start];
            }
            emu.program_size = data.length;
        }

        // -------------------------------------------------------------------------
        // Utility functions
        // -------------------------------------------------------------------------

        function getPC() public view returns (uint16) {
            return emu.pc;
        }

        function getRAMValueAt(uint256 index) public view returns (uint8) {
            require(index < RAM_SIZE, "RAM index out of bounds");
            return emu.ram[index];
        }

        function getVRegister(uint256 index) public view returns (uint8) {
            require(index < NUM_REGS, "V register index out of bounds");
            return emu.v_reg[index];
        }

        function setVRegister(uint8 index, uint8 value) public {
            require(index < NUM_REGS, "V register index out of bounds");
            emu.v_reg[index] = value;
        }

        function getIRegister() public view returns (uint16) {
            return emu.i_reg;
        }

        function setIRegister(uint16 value) public {
            emu.i_reg = value;
        }

        function setRAMValueAt(uint256 index, uint8 value) public {
            require(index < RAM_SIZE, "RAM index out of bounds");
            emu.ram[index] = value;
        }

        function getDelayTimer() public view returns (uint8) {
            return emu.dt;
        }

        function setDelayTimer(uint8 value) public {
            emu.dt = value;
        }

        function getSoundTimer() public view returns (uint8) {
            return emu.st;
        }

        function setSoundTimer(uint8 value) public {
            emu.st = value;
        }

        function getSP() public view returns (uint16) {
            return emu.sp;
        }

        function getStackValue(uint256 index) public view returns (uint16) {
            require(index < STACK_SIZE, "Stack index out of bounds");
            return emu.stack[index];
        }

        function setStackValue(uint256 index, uint16 value) public {
            require(index < STACK_SIZE, "Stack index out of bounds");
            emu.stack[index] = value;
        }

        function setSP(uint16 value) public {
            emu.sp = value;
        }

        function setScreenPixel(uint256 index, bool value) public {
            require(index < SCREEN_WIDTH * SCREEN_HEIGHT, "Index out of bounds");
            emu.screen[index] = value;
        }

        function isDisplayCleared() public view returns (bool) {
            for (uint256 i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) {
                if (emu.screen[i]) {
                    return false;
                }
            }
            return true;
        }
    }
}

#[tokio::main]
async fn main() {
    let args: Vec<_> = env::args().collect();
    if args.len() != 2 {
        println!("Usage: cargo run path/to/game");
        return;
    }

    // Setup SDL
    let sdl_context = sdl2::init().unwrap();
    let video_subsystem = sdl_context.video().unwrap();
    let window = video_subsystem
        .window("Chip-8 Emulator", WINDOW_WIDTH, WINDOW_HEIGHT)
        .position_centered()
        .opengl()
        .build()
        .unwrap();

    let mut canvas = window.into_canvas().present_vsync().build().unwrap();
    canvas.clear();
    canvas.present();
    let mut event_pump = sdl_context.event_pump().unwrap();
    // testing anvil account
    let signer: PrivateKeySigner = PrivateKeySigner::from_str(
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    )
    .unwrap();
    let wallet = EthereumWallet::from(signer);

    let provider = ProviderBuilder::new()
        .with_recommended_fillers()
        .wallet(wallet)
        .on_http(Url::from_str("http://localhost:8545").unwrap());

    // Get node info using the Anvil API.
    let info = provider.anvil_node_info().await.unwrap();

    println!("Node info: {:#?}", info);

    let chip8 = Emu::deploy(&provider).await.unwrap();
    // commented out, address that deployed on sepolia
    // let address = Address::from_str("0x8494dba7A8958629fE3e55D8F7F5eAF22978a467").unwrap();
    // let chip8 = Emu::new(address, &provider);

    let mut rom = File::open(&args[1]).expect("Unable to open file");
    let mut buffer = Vec::new();

    rom.read_to_end(&mut buffer).unwrap();
    println!("Loaded ROM with {:?} bytes", buffer);
    let builder = chip8.load(buffer.to_vec());
    builder.call().await.unwrap();
    // 250ms
    let tx = builder.send().await.unwrap().get_receipt().await.unwrap();
    println!("load tx: {:?}", tx);
    let r = chip8.getRAMValueAt(U256::from(512)).call().await.unwrap();
    // Check loaded successfully
    assert_eq!(r._0, buffer[0]);

    'gameloop: loop {
        let now = std::time::Instant::now();
        for evt in event_pump.poll_iter() {
            match evt {
                Event::Quit { .. }
                | Event::KeyDown {
                    keycode: Some(Keycode::Escape),
                    ..
                } => {
                    break 'gameloop;
                }
                Event::KeyDown {
                    keycode: Some(key), ..
                } => {
                    if let Some(k) = key2btn(key) {
                        let builder = chip8.keypress(U256::from(k), true);
                        builder.call().await.unwrap();

                        let tx = builder.send().await.unwrap();
                        println!("⭐️ key {:?} down tx: {:?}", key, tx);
                    }
                }
                Event::KeyUp {
                    keycode: Some(key), ..
                } => {
                    if let Some(k) = key2btn(key) {
                        let builder = chip8.keypress(U256::from(k), false);
                        builder.call().await.unwrap();

                        let tx = builder.send().await.unwrap();
                        println!("⭐️ key {:?} up tx: {:?}", key, tx);
                    }
                }
                _ => (),
            }
        }

        // TODO: I want to have tick per frame
        // for _ in 0..TICKS_PER_FRAME {}
        let builder = chip8.tick();
        builder.call().await.unwrap();
        // 250ms
        let tx = builder.send().await.unwrap().get_receipt().await.unwrap();
        println!("tx:{:?}", tx);

        let pc = chip8.getPC().call().await.unwrap();
        println!("PC: {:?}", pc._0);
        chip8.tickTimers().call().await.unwrap();
        draw_screen(&chip8, &mut canvas).await;

        let end = std::time::Instant::now();
        println!("⌛️ duration :{:?}", end.duration_since(now));
    }
}

async fn draw_screen<T, P, N>(emu: &EmuInstance<T, P, N>, canvas: &mut Canvas<Window>)
where
    T: Transport + Clone,
    P: Provider<T, N>,
    N: Network,
{
    // Clear canvas as black
    canvas.set_draw_color(Color::RGB(0, 0, 0));
    canvas.clear();

    let builder = emu.getDisplay();
    let screen_buf = builder.call().await.unwrap()._0;

    // Now set draw color to white, iterate through each point and see if it should be drawn
    canvas.set_draw_color(Color::RGB(255, 255, 255));
    for (i, pixel) in screen_buf.iter().enumerate() {
        if *pixel {
            // Convert our 1D array's index into a 2D (x,y) position
            let x = (i % SCREEN_WIDTH) as u32;
            let y = (i / SCREEN_WIDTH) as u32;

            // Draw a rectangle at (x,y), scaled up by our SCALE value
            let rect = Rect::new((x * SCALE) as i32, (y * SCALE) as i32, SCALE, SCALE);
            canvas.fill_rect(rect).unwrap();
        }
    }
    canvas.present();
}

/*
    Keyboard                    Chip-8
    +---+---+---+---+           +---+---+---+---+
    | 1 | 2 | 3 | 4 |           | 1 | 2 | 3 | C |
    +---+---+---+---+           +---+---+---+---+
    | Q | W | E | R |           | 4 | 5 | 6 | D |
    +---+---+---+---+     =>    +---+---+---+---+
    | A | S | D | F |           | 7 | 8 | 9 | E |
    +---+---+---+---+           +---+---+---+---+
    | Z | X | C | V |           | A | 0 | B | F |
    +---+---+---+---+           +---+---+---+---+
*/

fn key2btn(key: Keycode) -> Option<usize> {
    match key {
        Keycode::Num1 => Some(0x1),
        Keycode::Num2 => Some(0x2),
        Keycode::Num3 => Some(0x3),
        Keycode::Num4 => Some(0xC),
        Keycode::Q => Some(0x4),
        Keycode::W => Some(0x5),
        Keycode::E => Some(0x6),
        Keycode::R => Some(0xD),
        Keycode::A => Some(0x7),
        Keycode::S => Some(0x8),
        Keycode::D => Some(0x9),
        Keycode::F => Some(0xE),
        Keycode::Z => Some(0xA),
        Keycode::X => Some(0x0),
        Keycode::C => Some(0xB),
        Keycode::V => Some(0xF),
        _ => None,
    }
}
