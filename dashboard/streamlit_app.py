"""Tableau de bord Superstore Sales (Streamlit in Snowflake).

Lit uniquement les trois tables de la couche GOLD produites par dbt.
"""
import altair as alt
import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Superstore Sales", layout="wide")

BLEU = "#1f6feb"
VERT = "#2da44e"


def charger(table: str) -> pd.DataFrame:
    df = get_active_session().table(f"SUPERSTORE_DB.GOLD.{table}").to_pandas()
    df.columns = [c.lower() for c in df.columns]
    for col in df.columns:
        if col not in ("region", "category", "order_month"):
            df[col] = pd.to_numeric(df[col])
    return df


def dollars(valeur: float) -> str:
    return f"{valeur:,.0f} $".replace(",", " ")


region = charger("AGG_SALES_BY_REGION")
categorie = charger("AGG_SALES_BY_CATEGORY")
mensuel = charger("AGG_MONTHLY_SALES")
mensuel["order_month"] = pd.to_datetime(mensuel["order_month"])

st.title("Superstore Sales : performances commerciales")
st.caption("Source : SUPERSTORE_DB.GOLD (tables agrégées dbt), commandes de 2014 à 2017")

# Indicateurs clés
ca_total = region["total_sales"].sum()
benefice_total = region["total_profit"].sum()
k1, k2, k3, k4 = st.columns(4)
k1.metric("Chiffre d'affaires total", dollars(ca_total))
k2.metric("Bénéfice total", dollars(benefice_total))
k3.metric("Commandes", f"{int(region['nb_orders'].sum()):,}".replace(",", " "))
k4.metric("Marge", f"{benefice_total / ca_total:.1%}".replace(".", ","))

st.divider()

# Ventes par région et par catégorie
g1, g2 = st.columns(2)

with g1:
    st.subheader("Ventes par région")
    st.altair_chart(
        alt.Chart(region)
        .mark_bar(color=BLEU)
        .encode(
            x=alt.X("region:N", sort="-y", title=None, axis=alt.Axis(labelAngle=0)),
            y=alt.Y("total_sales:Q", title="Chiffre d'affaires ($)", axis=alt.Axis(format="~s")),
            tooltip=[
                alt.Tooltip("region:N", title="Région"),
                alt.Tooltip("total_sales:Q", title="CA ($)", format=",.0f"),
                alt.Tooltip("total_profit:Q", title="Bénéfice ($)", format=",.0f"),
                alt.Tooltip("nb_orders:Q", title="Commandes"),
            ],
        )
        .properties(height=320),
        use_container_width=True,
    )

with g2:
    st.subheader("Ventes par catégorie")
    st.altair_chart(
        alt.Chart(categorie)
        .mark_bar(color=BLEU)
        .encode(
            x=alt.X("category:N", sort="-y", title=None, axis=alt.Axis(labelAngle=0)),
            y=alt.Y("total_sales:Q", title="Chiffre d'affaires ($)", axis=alt.Axis(format="~s")),
            tooltip=[
                alt.Tooltip("category:N", title="Catégorie"),
                alt.Tooltip("total_sales:Q", title="CA ($)", format=",.0f"),
                alt.Tooltip("total_profit:Q", title="Bénéfice ($)", format=",.0f"),
                alt.Tooltip("total_quantity:Q", title="Quantité"),
            ],
        )
        .properties(height=320),
        use_container_width=True,
    )

# Évolution mensuelle
st.subheader("Évolution mensuelle des ventes")
evolution = mensuel.melt(
    id_vars="order_month",
    value_vars=["total_sales", "total_profit"],
    var_name="mesure",
    value_name="montant",
)
evolution["mesure"] = evolution["mesure"].map(
    {"total_sales": "Chiffre d'affaires", "total_profit": "Bénéfice"}
)
st.altair_chart(
    alt.Chart(evolution)
    .mark_line(point=True)
    .encode(
        x=alt.X("order_month:T", title=None, axis=alt.Axis(format="%m/%Y")),
        y=alt.Y("montant:Q", title="Montant ($)", axis=alt.Axis(format="~s")),
        color=alt.Color(
            "mesure:N",
            title=None,
            scale=alt.Scale(domain=["Chiffre d'affaires", "Bénéfice"], range=[BLEU, VERT]),
            legend=alt.Legend(orient="top"),
        ),
        tooltip=[
            alt.Tooltip("order_month:T", title="Mois", format="%m/%Y"),
            alt.Tooltip("mesure:N", title="Mesure"),
            alt.Tooltip("montant:Q", title="Montant ($)", format=",.0f"),
        ],
    )
    .properties(height=340),
    use_container_width=True,
)
