"""Execute 03_dashboard_streamlit.sql sur Snowflake, PUT compris.

    python snowflake/deployer_dashboard.py
"""
from charger_raw import RACINE, connexion

SCRIPT = RACINE / "snowflake" / "03_dashboard_streamlit.sql"
APP = RACINE / "dashboard" / "streamlit_app.py"


def main():
    sql = SCRIPT.read_text().replace("file://dashboard/streamlit_app.py", f"file://{APP}")
    with connexion() as cnx:
        dernier = cnx.execute_string(sql, remove_comments=True)[-1]
        colonnes = [c[0] for c in dernier.description]
        for ligne in dernier.fetchall():
            infos = dict(zip(colonnes, ligne))
            print(infos.get("name"), "|", infos.get("title"), "|", infos.get("url_id"))


if __name__ == "__main__":
    main()
