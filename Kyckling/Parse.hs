module Kyckling.Parse (parseAST) where

import System.IO
import Control.Monad
import Text.ParserCombinators.Parsec
import Text.ParserCombinators.Parsec.Expr
import Text.ParserCombinators.Parsec.Language
import qualified Text.ParserCombinators.Parsec.Token as Token

import qualified Kyckling.AST as AST

languageDef =
  emptyDef { Token.commentStart    = "/*"
           , Token.commentEnd      = "*/"
           , Token.commentLine     = "//"
           , Token.reservedNames   = [ "if", "else"
                                     , "true", "false"
                                     , "int", "bool"
                                     , "assert"
                                     ]
           , Token.reservedOpNames = [ "+",  "-",  "*"
                                     , "+=", "-=", "*=", "=", "++", "--"
                                     , "==", "!=", "<", ">", "<=", ">="
                                     , "&&", "||", "!"
                                     , ":", "?"
                                     , "[]"
                                     ]
           }

lexer = Token.makeTokenParser languageDef

identifier = Token.identifier lexer
reserved   = Token.reserved   lexer
reservedOp = Token.reservedOp lexer
parens     = Token.parens     lexer
integer    = Token.integer    lexer
semi       = Token.semi       lexer
whiteSpace = Token.whiteSpace lexer
braces     = Token.braces     lexer
brackets   = Token.brackets   lexer
commaSep1  = Token.commaSep1  lexer

constant name fun = reserved name >> return fun

binary  name fun = Infix (reservedOp name >> return fun)
prefix  name fun = Prefix (reservedOp name >> return fun)
postfix name fun = Postfix (reservedOp name >> return fun)

expr :: Parser AST.Expr
expr = do e <- expr'
          tern <- optionMaybe (reserved "?")
          case tern of
            Just _ -> do a <- expr
                         reserved ":"
                         b <- expr
                         return $ AST.Ternary e a b
            Nothing -> return e

expr' = buildExpressionParser operators term

operators = [ [prefix "-"  (AST.Prefix AST.Uminus )          ,
               prefix "+"  (AST.Prefix AST.Uplus  )          ]
            , [binary "*"  (AST.Infix  AST.Times  ) AssocLeft]
            , [binary "+"  (AST.Infix  AST.Plus   ) AssocLeft,
               binary "-"  (AST.Infix  AST.Minus  ) AssocLeft]
            , [binary ">"  (AST.Infix  AST.Greater) AssocNone,
               binary "<"  (AST.Infix  AST.Less   ) AssocNone,
               binary ">=" (AST.Infix  AST.Geq    ) AssocNone,
               binary "<=" (AST.Infix  AST.Leq    ) AssocNone]
            , [binary "==" (AST.Infix  AST.Eq     ) AssocLeft,
               binary "!=" (AST.Infix  AST.NonEq  ) AssocLeft]
            , [prefix "!"  (AST.Prefix AST.Not    )          ]
            , [binary "&&" (AST.Infix  AST.And    ) AssocLeft,
               binary "||" (AST.Infix  AST.Or     ) AssocLeft]
            ]

term =  parens expr
    <|> constant "true"  (AST.BoolConst True)
    <|> constant "false" (AST.BoolConst False)
    <|> liftM AST.IntConst integer
    <|> liftM AST.LVal lval

lval =  try (liftM2 AST.ArrayElem identifier (brackets expr))
    <|> liftM AST.Var identifier

stmt :: Parser AST.Stmt
stmt =  stmt'
    <|> liftM AST.Block (braces $ many stmt')

stmt' :: Parser AST.Stmt
stmt' =  updateStmt
     <|> declareStmt
     <|> ifStmt
     <|> assertStmt

atomicStmt p = do { s <- p; semi; return s }

updateStmt = atomicStmt $ do v <- lval
                             choice $ map (\(t, o) -> reserved t >> return (o v)) unaryUpdates ++
                                      map (\(t, o) -> reserved t >> liftM (AST.Update v o) expr) binaryUpdates
  where
    unaryUpdates  = [("++", AST.Increment), ("--", AST.Decrement)]
    binaryUpdates = [("=",  AST.Assign), ("+=", AST.Add), ("-=", AST.Subtract), ("*=", AST.Multiply)]

declareStmt = atomicStmt $ liftM2 AST.Declare typ (commaSep1 definition)
  where
    definition = liftM2 (,) identifier maybeBody
    maybeBody  = optionMaybe (reservedOp "=" >> expr)

ifStmt = reserved "if" >> liftM3 AST.If (parens expr) stmt maybeElse
  where
    maybeElse = optionMaybe (reserved "else" >> stmt)

assertStmt = atomicStmt (reserved "assert" >> liftM AST.Assert expr)

typ :: Parser AST.Type
typ = do t <- atomicTyp
         arrs <- many (reserved "[]")
         return $ foldr (const AST.Array) t arrs

atomicTyp =  constant "int"  AST.I
         <|> constant "bool" AST.B

ast :: Parser AST.AST
ast = whiteSpace >> liftM AST.AST (many stmt)

parseAST :: SourceName -> String -> Either ParseError AST.AST
parseAST = parse ast