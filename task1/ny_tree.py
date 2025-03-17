import pandas as pd
import json
from sqlalchemy import create_engine
import requests
from psycopg2 import connect

df = pd.read_csv('2015-street-tree-census-tree-data.csv')
# проверка на дубликаты строк
df = df.drop(df[df.duplicated()].index)
# проверка на null
print(df.isnull().sum())
# большинство null у мертвых деревьев и пней, наверное удалять их так себе идея, может нужно будет узнать процент мертвых деревьев или что-то в этом роде

# пример проверки уникальных значений в столбце
df.sidewalk.unique()
# приведение к дате
df['created_at'] = pd.to_datetime(df['created_at'], infer_datetime_format=True)

# приведение к boolesn там, где это возможно
df['curb_loc'] = df['curb_loc'].map({'OnCurb': True, 'OffsetFromCurb': False})
df['root_stone'] = df['root_stone'].map({'Yes': True,'No': False})
df['root_grate'] = df['root_grate'].map({'Yes': True,'No': False})
df['root_other'] = df['root_other'].map({'Yes': True,'No': False})
df['trunk_wire'] = df['trunk_wire'].map({'Yes': True,'No': False})
df['trnk_light'] = df['trnk_light'].map({'Yes': True,'No': False})
df['trnk_other'] = df['trnk_other'].map({'Yes': True,'No': False})
df['brch_light'] = df['brch_light'].map({'Yes': True,'No': False})
df['brch_shoe'] = df['brch_shoe'].map({'Yes': True,'No': False})
df['brch_other'] = df['brch_other'].map({'Yes': True,'No': False})

df = df.rename(columns={'community board': 'community_board', 'council district': 'council_district', 'census tract': 'census_tract'})
# df.info()

engine = create_engine(f'postgresql://postgres@localhost:5433/postgres')
with requests.Session() as session:
    df.to_sql('tree_analysis', con=engine, if_exists='replace', index=False)