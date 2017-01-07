module Game.Sequoia.Graphics where

import qualified Data.Text as T
import           Game.Sequoia.Color (Color, black)
import           Game.Sequoia.Types
import           Graphics.Rendering.Cairo.Matrix (Matrix)


data FontWeight = LightWeight
                | NormalWeight
                | BoldWeight
                deriving (Show, Eq, Ord, Enum, Read)

data FontStyle = NormalStyle
               | ObliqueStyle
               | ItalicStyle
               deriving (Show, Eq, Ord, Enum, Read)

data Text = Text {
  textUTF8 :: T.Text,
  textColor :: Color,
  textTypeface :: T.Text,
  textHeight :: Double,
  textWeight :: FontWeight,
  textStyle :: FontStyle
} deriving (Show, Eq)

data Crop = Crop Int Int Int Int
  deriving (Show, Eq)

data Element = CollageElement Int Int (Maybe (Double, Double)) [Form]
             | ImageElement (Maybe Crop) FilePath
             | TextElement Text
             deriving (Show, Eq)

image :: FilePath -> Element
image src = ImageElement Nothing src

croppedImage :: Crop -> FilePath -> Element
croppedImage crop src = ImageElement (Just crop) src

data Form = Form {
  formTheta :: Double,
  formScale :: Double,
  formX :: Double,
  formY :: Double,
  formStyle :: FormStyle
} deriving (Show, Eq)

data FillStyle = Solid Color
               | Texture String
               deriving (Show, Eq, Ord, Read)

data LineCap = FlatCap
             | RoundCap
             | PaddedCap
             deriving (Show, Eq, Enum, Ord, Read)

data LineJoin = SmoothJoin
              | SharpJoin Double
              | ClippedJoin
              deriving (Show, Eq, Ord, Read)

data LineStyle = LineStyle {
  lineColor :: Color,
  lineWidth :: Double,
  lineCap :: LineCap,
  lineJoin :: LineJoin,
  lineDashing :: [Double],
  lineDashOffset :: Double
} deriving (Show, Eq)

defaultLine :: LineStyle
defaultLine = LineStyle {
  lineColor = black,
  lineWidth = 1,
  lineCap = FlatCap,
  lineJoin = SharpJoin 10,
  lineDashing = [],
  lineDashOffset = 0
}

solid :: Color -> LineStyle
solid color = defaultLine { lineColor = color }

dashed :: Color -> LineStyle
dashed color = defaultLine { lineColor = color, lineDashing = [8, 4] }

dotted :: Color -> LineStyle
dotted color = defaultLine { lineColor = color, lineDashing = [3, 3] }

data FormStyle = PathForm LineStyle Path |
                 ShapeForm (Either LineStyle FillStyle) Shape |
                 ElementForm Element |
                 GroupForm (Maybe Matrix) [Form] deriving (Show, Eq)

form :: FormStyle -> Form
form style = Form { formTheta = 0, formScale = 1, formX = 0, formY = 0, formStyle = style }

fill :: FillStyle -> Shape -> Form
fill style = form . ShapeForm (Right style)

filled :: Color -> Shape -> Form
filled = fill . Solid

textured :: String -> Shape -> Form
textured = fill . Texture

outlined :: LineStyle -> Shape -> Form
outlined style shape = form (ShapeForm (Left style) shape)

traced :: LineStyle -> Path -> Form
traced style p = form (PathForm style p)

traced' :: Color -> Shape -> Form
traced' c = outlined (defaultLine { lineColor = c
                                  , lineDashing = [8, 4]
                                  })

outlined' :: Color -> Shape -> Form
outlined' c = outlined (defaultLine { lineColor = c } )

sprite :: FilePath -> Form
sprite = toForm . image

toForm :: Element -> Form
toForm = form . ElementForm

blank :: Form
blank = group []

group :: [Form] -> Form
group = form . GroupForm Nothing

groupTransform :: Matrix -> [Form] -> Form
groupTransform matrix forms = form (GroupForm (Just matrix) forms)

rotate :: Double -> Form -> Form
rotate t f = f { formTheta = t + formTheta f }

scale :: Double -> Form -> Form
scale n f = f { formScale = n * formScale f }

move :: V2 -> Form -> Form
move (V2 rx ry) f = f { formX = rx + formX f, formY = ry + formY f }
move _ _ = undefined

collage :: Int -> Int -> [Form] -> Element
collage w h = CollageElement w h Nothing

centeredCollage :: Int -> Int -> [Form] -> Element
centeredCollage w h = CollageElement w h (Just (realToFrac w / 2, realToFrac h / 2))

fixedCollage :: Int -> Int -> (Double, Double) -> [Form] -> Element
fixedCollage w h (x, y) = CollageElement w h (Just (realToFrac w / 2 - x, realToFrac h / 2 - y))

type Path = [(Double, Double)]

path :: [V2] -> Path
path = fmap unpackV2

segment :: (Double, Double) -> (Double, Double) -> Path
segment p1 p2 = [p1, p2]

data Shape = PolygonShape Path
           | RectangleShape (Double, Double)
           | ArcShape (Double, Double) Double Double Double (Double, Double)
           deriving (Show, Eq, Ord, Read)

polygon :: [V2] -> Shape
polygon = PolygonShape . path

rect :: Double -> Double -> Shape
rect w h = RectangleShape (w, h)

square :: Double -> Shape
square n = rect n n

oval :: Double -> Double -> Shape
oval = ellipse

ellipse :: Double -> Double -> Shape
ellipse w h = polygon
              $ fmap (rad2rel . (* drad) . fromIntegral) [0..samples]
  where
    samples = 15 :: Int
    drad = 2 * pi / fromIntegral samples
    rad2rel rad = V2 (cos rad * w / 2) (sin rad * h / 2)

circle :: Double -> Shape
circle r = ArcShape (0, 0) 0 (2 * pi) r (1, 1)

arc :: V2 -> Double -> Double -> Shape
arc size theta phi = ArcShape (0, 0) theta phi 1 (unpackV2 size)

ngon :: Int -> Double -> Shape
ngon n r = PolygonShape (map (\i -> (r * cos (t * i), r * sin (t * i))) [0 .. fromIntegral (n - 1)])
  where
    m = fromIntegral n
    t = 2 * pi / m

