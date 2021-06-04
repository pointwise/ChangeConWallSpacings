# ChangeConWallSpacings
Copyright 2021 Cadence Design Systems, Inc. All rights reserved worldwide.

This script is designed to help adjust many wall-spacing constraints to the same value. It works for structured grids and for unstructured grids that do not contain prism blocks or T-Rex blocks.

## Selecting Databases
When the script is run, you start by pressing the “Select Wall Database Surfaces” button. This will launch a mode that allows you to select database entities. When you press the “done” button, the script will find the wall-spacing constraints for the databases you chose and highlight their corresponding connectors in white. Only spacing constraints that point toward one of your selected databases, but do not lie on the surface, will be selected.

## Warning
Under ordinary circumstances, after being highlighted, connectors will be returned to their original color when the script exits. However, if the script crashes, or you press the “Interrupt Script” button in Pointwise, this will not happen. If this is a problem, you can press CTRL+Z in Pointwise and the script execution will be undone.

## Tolerance
Sometimes, your grid will have some connectors that are near to, but don’t quite touch the database entities. If you raise the tolerance, spacing constraints on nodes that are within the given tolerance value of a database surface will be selected. You should be aware that, if you set the tolerance too high, some spacing constraints will no longer be selected. This has to do with some specifics of the selection algorithm. The connectors containing the selected spacing constraints will be highlighted in white. 

## Spacing
The current spacing of your chosen connectors (or their average) will be displayed, and you can give a new spacing. The new spacing will not be applied to your spacing constraints until you press “Apply” or “OK.”

## Modify Distributions
Connectors with General distributions (created by extrusions and other operations) do not often respond well to spacing constraints. If you check the “Modify Distributions” check box, you can choose to change General, or All distributions to Tanh or MRQS in the corresponding drop-down menus.

## Preserve Inital Spacing Constraints
This check box allows you to preserve the spacing constraints on the other ends of connectors from the spacing constraints you have selected. If a spacing constraint is unconstrained/automatic, it may change a lot if the spacing constraint at the other end of its connector is changed. This option will keep that from happening.

## Initializing Affected Domains and Blocks
Adjusting spacing constraints will often modify existing domains and blocks that are connected to them. These options tell the script to initialize domains and/or blocks that are affected by the spacing change, so that you don’t have to.

## Disclaimer
This file is licensed under the Cadence Public License Version 1.0 (the "License"), a copy of which is found in the LICENSE file, and is distributed "AS IS." 
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE. 
Please see the License for the full text of applicable terms.
