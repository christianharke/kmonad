{-# LANGUAGE DeriveAnyClass #-}
module KMonad.App.Cfg.Types where


import KMonad.Prelude


import KMonad.Gesture
import KMonad.Logging.Cfg
import KMonad.App.Cfg.Expr.Cmd
import KMonad.App.Cfg.Expr.Path
import KMonad.Keyboard.Types (DelayRate(..))

import System.IO

import Data.Either.Validation (Validation(..))
import GHC.Generics (Generic)

import qualified RIO.HashMap as M
import qualified RIO.Text as T
import qualified Dhall as D

--------------------------------------------------------------------------------

type CmdSpec = Text
type FileSpec = Text
type KeyInputSpec = Text
type KeyOutputSpec = Text
type KeyRepeatSpec = Text
type LogLevelSpec = Text
type GestureExpr = Text

 -------------------------------------------------------------------------------

data RunType = FullRun | CfgTest | EvTest
  deriving (Eq, Show)

data KeyInputCfg
  = LinEvdevSrc Path
  | WinHookSrc
  | MacIOKitSrc (Maybe Text)
  | CmdSrc Cmd
  | StdinSrc
  deriving (Eq, Show)

data KeyOutputCfg
  = LinUinputSnk (Maybe Text)
  | WinSendSnk
  | MacKextSink
  | CmdSnk Cmd
  | StdoutSnk
  deriving (Eq, Show)

data KeyRepeatCfg
  = Simulate DelayRate
  | EchoOS
  | IgnoreRepeat
  deriving (Eq, Show)
  -- NOTE^: Here we can add 'detect repeat from OS then ping' idea from github

data LocaleCfg = LocaleCfg
  { _namedCodes :: M.HashMap Name Natural
  , _namedGestures :: M.HashMap Name (Gesture Natural)
  } deriving (Eq, Show)

data RunCfg = RunCfg
  { _cfgPath :: Path
  , _kbdPath :: Path
  , _cmdAllow :: Bool
  , _runType :: RunType
  } deriving (Eq, Show)

data KioCfg = KioCfg
  { _keyRepeatCfg :: KeyRepeatCfg
  , _fallthrough  :: Bool
  , _keyInputCfg  :: KeyInputCfg
  , _keyOutputCfg :: KeyOutputCfg
  , _preKIOcmd    :: Maybe Cmd
  , _postKIOcmd   :: Maybe Cmd
  } deriving (Eq, Show)

newtype LogCfg = LogCfg { _logLevel :: LogLevel}
  deriving (Eq, Show)

data AppCfg = AppCfg
  { _appLocaleCfg :: LocaleCfg
  , _appLogCfg :: LogCfg
  , _appKioCfg :: KioCfg
  , _appRunCfg :: RunCfg
  } deriving (Eq, Show)


defCfg :: AppCfg
defCfg = AppCfg
  { _appLocaleCfg = LocaleCfg
    { _namedCodes    = M.fromList []
    , _namedGestures = M.fromList []
    }
  , _appLogCfg = LogCfg
    { _logLevel = LevelWarn
    }
  , _appKioCfg = KioCfg
    { _keyRepeatCfg = IgnoreRepeat
    , _fallthrough = False
    , _keyInputCfg = StdinSrc
    , _keyOutputCfg = StdoutSnk
    , _preKIOcmd = Nothing
    , _postKIOcmd = Nothing
    }
  , _appRunCfg = RunCfg
    { _cfgPath = "xdgcfg:kmonad.dhall" ^. from _PathExpr
    , _kbdPath = "xdgcfg:keymap.kbd" ^. from _PathExpr
    , _cmdAllow = False
    , _runType = FullRun
    }
  }

-- lenses ----------------------------------------------------------------------

makeClassy ''RunCfg
makeClassy ''LocaleCfg
makeClassy ''KioCfg
makeClassy ''LogCfg
makeClassy ''AppCfg

instance HasLogCfg AppCfg where logCfg = appLogCfg
instance HasRunCfg AppCfg where runCfg = appRunCfg

-- invoc  ----------------------------------------------------------------------

data Invoc = Invoc
  { _irunType :: RunType
  , _icfgFile :: Maybe FileSpec
  , _ikeymapFile :: Maybe FileSpec
  , _ifallthrough :: Maybe Bool
  , _icmdAllow :: Maybe Bool
  , _ilogLevel :: Maybe LogLevelSpec
  , _ikeyRepeat :: Maybe KeyRepeatSpec
  , _ikeyInputCfg :: Maybe KeyInputSpec
  , _ikeyOutputCfg :: Maybe KeyOutputSpec
  , _ipreKIOcmd :: Maybe CmdSpec
  , _ipostKIOcmd :: Maybe CmdSpec
  } deriving (Eq, Show)
makeClassy ''Invoc

defCfgFile :: FileSpec
defCfgFile = "cfg:kmonad.dhall"

-- dhall -----------------------------------------------------------------------

data DEntry k v = DEntry
  { _mapKey :: k
  , _mapValue :: v
  } deriving (Generic, D.FromDhall, Show)
makeLenses ''DEntry

type DMap k v= [DEntry k v]

-- _Tuple :: Iso' (DEntry k v) (k, v)
-- _Tuple = iso (\e -> (e^.mapKey, e^.mapValue)) $ uncurry DEntry


-- | Use '_DMap' as a view of an alist as a DMap, and 'from _DMap' as its inverse
_DMap :: Iso' [(k, v)] (DMap k v)
_DMap = iso (map $ uncurry DEntry) (map $ view mapKey &&& view mapValue)

-- | The settings that we want to expose to Dhall
--
-- This explicitly leaves out:
-- cfgFile: because it would point at self
-- runType: because it can only be provided by Invoc
--
-- NOTE: the difference between this and 'Invoc', here the only time we use
-- 'Maybe' is to denote the setting of not-doing-something. In 'Invoc' 'Nothing'
-- denotes do-not-change-this-setting. This is because we encode our app
-- defaults *in dhall*. So the default invoc settings are to change nothing, the
-- default CfgFile settings *are* the app defaults.
data DhallCfg = DhallCfg
  { _dcodeNames    :: [DEntry Name Natural]
  , _dgestureNames :: [DEntry Name GestureExpr]
  , _dfallthrough  :: Bool
  , _dcmdAllow     :: Bool
  , _dlogLevel     :: LogLevelSpec
  , _dkeyInputCfg  :: KeyInputSpec
  , _dkeyOutputCfg :: KeyOutputSpec
  , _dkeymapFile   :: PathExpr
  , _dkeyRepeat    :: Maybe KeyRepeatSpec
  , _dpreKIOcmd    :: Maybe CmdSpec
  , _dpostKIOcmd   :: Maybe CmdSpec
  } deriving (Generic, D.FromDhall, Show)
makeClassy ''DhallCfg


-- loadDhallCfg :: MonadIO m => FilePath -> m DhallCfg
-- loadDhallCfg f = do
--   let opt = D.defaultInterpretOptions { D.fieldModifier = T.drop 1 }
--   let dec = D.genericAutoWith opt
--   liftIO $ D.inputFile dec f


-- testDhall :: IO ()
-- testDhall = pPrint =<< loadDhallCfg "/home/david/prj/kmonad/cfg/linux.dhall"
