This script helps with bulk registration / revocation.

Preparation:
1. Update `Move.toml` with the correct `repository` account.
2. Ensure to run the following with that account `aptos move run --function-id "0x3::token::opt_in_direct_transfer" --args bool:true --profile repository`

Each iteration:
1. Update the script with the appropriate names to seize / register
2. Compile the script: `aptos move compile`
3. Run the script: `aptos move run-script --compiled-script-path register/build/movement_names_register/bytecode_scripts/main.mv --profile admin`
