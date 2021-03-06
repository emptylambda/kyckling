module Kyckling.Program where

data Type = Integer
          | Boolean
          | Array Type
  deriving (Show, Eq)

data Var = Var String Type
  deriving (Show)

data UnaryOp = Negate
             | Positive
             | Negative
  deriving (Show)

data BinaryOp = And | Or
              | Greater | Less | Geq | Leq
              | Add | Subtract | Multiply
  deriving (Show)

data TernaryOp = IfElse
  deriving (Show)

data LValue = Variable Var
            | ArrayElem Var Expression
  deriving (Show)

data Expression = IntegerConst Integer
                | BoolConst Bool
                | Unary   UnaryOp   Expression
                | Binary  BinaryOp  Expression Expression
                | Ternary TernaryOp Expression Expression Expression
                | Eql Expression Expression
                | InEql Expression Expression
                | Ref LValue
  deriving (Show)

data Statement = Declare Var
               | Assign LValue Expression
               | If Expression [Statement] [Statement]
  deriving (Show)

data Assertion = Assertion Expression
  deriving (Show)

data Program = Program [Statement] [Assertion]
  deriving (Show)