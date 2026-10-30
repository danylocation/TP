"""Execute 01_setup_et_chargement_raw.sql sur Snowflake, PUT compris.

Les parametres de connexion sont lus dans le profil dbt (~/.dbt/profiles.yml,
profil `superstore`, cible `dev`) : aucun identifiant n'est ecrit ici.

    python snowflake/charger_raw.py
"""
from pathlib import Path

import snowflake.connector
import yaml
from cryptography.hazmat.primitives import serialization

RACINE = Path(__file__).resolve().parent.parent
SCRIPT = RACINE / "snowflake" / "01_setup_et_chargement_raw.sql"
CSV = RACINE / "data" / "Superstore.csv"


def connexion():
    profil = yaml.safe_load((Path.home() / ".dbt" / "profiles.yml").read_text())
    cible = profil["superstore"]["outputs"]["dev"]
    params = {
        "account": cible["account"],
        "user": cible["user"],
        "role": cible.get("role", "SYSADMIN"),
    }
    if "private_key_path" in cible:
        cle = serialization.load_pem_private_key(
            Path(cible["private_key_path"]).expanduser().read_bytes(), password=None
        )
        params["private_key"] = cle.private_bytes(
            serialization.Encoding.DER,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        )
    else:
        params["authenticator"] = cible.get("authenticator", "externalbrowser")
    return snowflake.connector.connect(**params)


def main():
    sql = SCRIPT.read_text().replace("file://data/Superstore.csv", f"file://{CSV}")
    with connexion() as cnx:
        curseurs = cnx.execute_string(sql, remove_comments=True)
        for cur in curseurs[-3:]:
            colonnes = [c[0] for c in cur.description]
            print(" | ".join(colonnes))
            for ligne in cur.fetchall():
                print(" | ".join(str(v) for v in ligne))
            print()


if __name__ == "__main__":
    main()
