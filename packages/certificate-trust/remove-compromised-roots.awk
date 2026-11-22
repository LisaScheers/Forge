# Apple groups certificates under ### organization and === subject headings.
/^(###|===) / { skip = 0 }
/^=== .*\/CN=(AAA Certificate Services|emSign ECC Root CA - G3)$/ { skip = 1 }
!skip
