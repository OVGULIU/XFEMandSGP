function [B] = xfemBmat(pt,e,type_elem,enrich_node,xCrl,GVertex,cont,node,element,MAT,tip_elem)

%declare global variables here
global elemType incR xc yc

sctr = element(e,:);
nn   = length(sctr);
[N,dNdxi] = lagrange_basis(elemType,pt);  % element shape functions
J0 = node(sctr,:)'*dNdxi;                 % element Jacobian matrix
invJ0 = inv(J0);
dNdx  = dNdxi*invJ0;                      % derivatives of N w.r.t XY
Gpt = N' * node(sctr,:);                  % GP in global coord, used

%Standard B matrix is computed always...
if cont == 1
    Bfem = zeros(3,2*nn) ;
    Bfem(1,1:2:2*nn) = dNdx(:,1)' ;
    Bfem(2,2:2:2*nn) = dNdx(:,2)' ;
    Bfem(3,1:2:2*nn) = dNdx(:,2)' ;
    Bfem(3,2:2:2*nn) = dNdx(:,1)' ;
else
    Bfem = [] ;
end

iwant = [ ] ;
%switch between non-enriched and enriched elements
if( any(enrich_node(sctr)) == 0 )
    B = Bfem ;
else
    Bxfem = [ ] ;
    %loop on nodes, check is node is enriched........
    for in = 1:nn
        %Enriched by H(x) at global gauss point
        if ( enrich_node(sctr(in)) == 2)
            if (type_elem(e,cont) == 2) || (type_elem(e,cont) == 3)  %node in a split element
                ref_elem = e;
                xCre = [xCrl(ref_elem,1) xCrl(ref_elem,2); xCrl(ref_elem,3) xCrl(ref_elem,4)];                 %each element has its crack!
                if (type_elem(e,cont) == 3)
                    distV = signed_distance(xCre,GVertex(ref_elem,:),0);
                    HV = sign(distV);
                    dist = signed_distance(xCre,Gpt,0);
                    Hgp  = sign(dist);
                    if HV * Hgp <= 0 %below or above the line relating the crack intersections?
                        Hgp = Hgp;
                    else
                        vv = [xCre(1,:); xCre(2,:); GVertex(ref_elem,:)];
                        flag = inhull(Gpt,vv); % is the point in the triangle formed by the crack ends and the vertex?
                        if flag == 1     % yes
                            Hgp =- Hgp;
                        else             % no
                            Hgp =  Hgp;
                        end
                    end
                    dist = signed_distance(xCre,node(sctr(in),:),0); % nodes are always outside the triangle..easy!
                    Hi  = sign(dist);
                    
                else %
                    % Enrichment function, H(x) at global Gauss point
                    dist = signed_distance(xCre,Gpt,16);
                    Hgp  = sign(dist);
                    % Enrichment function, H(x) at node "in"
                    dist = signed_distance(xCre,node(sctr(in),:),0);
                    Hi   = sign(dist);
                end % is vertex
                % Bxfem at node "in"
                BI_enr = [dNdx(in,1)*(Hgp - Hi) 0 ; 0 dNdx(in,2)*(Hgp - Hi) ;
                    dNdx(in,2)*(Hgp - Hi) dNdx(in,1)*(Hgp - Hi)];
            else    %if the element is not cut by a crack, the enrichment is always 0
                BI_enr = [0 0 ; 0 0 ; 0 0];
            end
            % Add to the total Bxfem
            Bxfem = [Bxfem BI_enr];
            clear BI_enr ;
            
            % ------------ Enriched by asymptotic functions -----------------------------------
        elseif ( enrich_node(sctr(in)) == 1) % B(x) enriched node
% %             if type_elem(e,1) == 1   %looking for the "tip" element
% %                 ref_elem = e;
% %             else    %trovo l'elemento/fessura a cui fa riferimento il nodo (SOLO 1 RIF AUTORIZZATO!!)
% %                 [sctrn,xx] = find(element == sctr(in));
% %                 [ele,xx] = find(type_elem(sctrn,:)==1);
% %                 ref_elem = sctrn(ele);
% %             end
%             if type_elem(e,1) == 1   %looking for the "tip" element
%                 ref_elem = e;
%             else    %trovo l'elemento/fessura a cui fa riferimento il nodo (SOLO 1 RIF AUTORIZZATO!!)
%                 [sctrn,xx] = find(element == sctr(in));
%                 [ele,xx] = find(type_elem(sctrn,:)==1);
%                 ref_elem = sctrn(ele);
%             end
            ref_elem = tip_elem(1) ;            
            % compute branch functions at Gauss point
            xCre  = [xCrl(ref_elem,1) xCrl(ref_elem,2); xCrl(ref_elem,3) xCrl(ref_elem,4)];
            seg   = xCre(2,:) - xCre(1,:);
            alpha = atan2(seg(2),seg(1));
            xTip  = [xCre(2,1) xCre(2,2)];
            QT    = [cos(alpha) sin(alpha); -sin(alpha) cos(alpha)];
            xp    = QT*(Gpt-xTip)';           % local coordinates
            r     = sqrt(xp(1)*xp(1)+xp(2)*xp(2));
            theta = atan2(xp(2),xp(1));
            
            if ( theta > pi | theta < -pi)
                disp (['something wrong with angle ',num2str(thet)]);
            end
            [Br,dBdx,dBdy] = branch_gp(r,theta,alpha,MAT);
            % compute branch functions at node "in"
            xp    = QT*(node(sctr(in),:)-xTip)';
            r     = sqrt(xp(1)*xp(1)+xp(2)*xp(2));
            theta = atan2(xp(2),xp(1));
            
            if ( theta > pi | theta < -pi)
                disp (['something wrong with angle ',num2str(thet)]);
            end
            [BrI] = branch_node(r,theta,MAT);
            
            % composants of Benr matrix
            
            aa = dNdx(in,1)*(Br(1)-BrI(1)) + N(in)*dBdx(1) ;
            bb = dNdx(in,2)*(Br(1)-BrI(1)) + N(in)*dBdy(1) ;
            B1_enr = [aa 0 ; 0 bb ; bb aa];
            
            aa = dNdx(in,1)*(Br(2)-BrI(2)) + N(in)*dBdx(2) ;
            bb = dNdx(in,2)*(Br(2)-BrI(2)) + N(in)*dBdy(2) ;
            B2_enr = [aa 0 ; 0 bb ; bb aa];
            
            aa = dNdx(in,1)*(Br(3)-BrI(3)) + N(in)*dBdx(3) ;
            bb = dNdx(in,2)*(Br(3)-BrI(3)) + N(in)*dBdy(3) ;
            B3_enr = [aa 0 ; 0 bb ; bb aa];
            
            aa = dNdx(in,1)*(Br(4)-BrI(4)) + N(in)*dBdx(4) ;
            bb = dNdx(in,2)*(Br(4)-BrI(4)) + N(in)*dBdy(4) ;
            B4_enr = [aa 0 ; 0 bb ; bb aa];
            
            BI_enr = [B1_enr B2_enr B3_enr B4_enr];
            clear B1_enr; clear B2_enr; clear B3_enr; clear B4_enr;
            Bxfem = [Bxfem BI_enr];
            clear BI_enr ;
        elseif( enrich_node(sctr(in)) == 3)
            % compute the enrichment function and derivatives
            % at gauss point
            x = Gpt(1);
            y = Gpt(2);
            d = sqrt((x-xc)^2+(y-yc)^2);
            Fgp    = abs(d - incR) ;
            dFdx = sign(Fgp)*(x-xc)/d;
            dFdy = sign(Fgp)*(y-yc)/d;
            
            % compute the enrichment function at node
            x = node(sctr(in),1);
            y = node(sctr(in),2);
            d = sqrt((x-xc)^2+(y-yc)^2);
            FI = abs(d - incR);
            
            % Bxfem at node "in"
            aa = dNdx(in,1)*(Fgp-FI) + N(in)*dFdx ;
            bb = dNdx(in,2)*(Fgp-FI) + N(in)*dFdy ;
            BI_enr = [aa 0; 0 bb; bb aa];
            
            % Add to the total Bxfem
            Bxfem = [Bxfem BI_enr];
            clear BI_enr ;
        end
    end          % end of loop on nodes
    % B matrix
    B = [ Bfem Bxfem ];
    clear Bfem; clear Bxfem;
end              % end of switch between enriched and non-enriched elements