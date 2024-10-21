#include <stdio.h> 
	#include <math.h> 
	 
	#define MAX_ASSIGN 50 
	 
	static int find_lowest(int assigns[MAX_ASSIGN], int scores[MAX_ASSIGN], 
	                int weights[MAX_ASSIGN], int num_assigns) { 
	   int lowest = (100 * 100) + 1; /*Will track lowest score */ 
	   int lowest_assigned_number = 50; /* Will track assignment num 
	                                       of lowest score */ 
	   int index = 50; /* Will track index of lowest score */ 
	   int i; /* used in for loops */ 
	 
	   for (i = 0; i < num_assigns; i++) { 
	      if (assigns[i] != 0) { 
	         int current = (weights[i] * scores[i]); 
	 
	         if (current < lowest) { 
	            lowest = current; 
	            lowest_assigned_number = assigns[i]; 
	            index = i; 
	         } else if (current == lowest) { 
	            if (assigns[i] < lowest_assigned_number) { 
	               lowest_assigned_number = assigns[i]; 
	               index = i; 
	            } 
	 
	         } 
	      } 
	   } 
	   return index; 
	} 
	 
	double calc_numeric(int assigns[MAX_ASSIGN], int scores[MAX_ASSIGN], 
	                    int weights[MAX_ASSIGN], int late_days[MAX_ASSIGN], 
	                    int penalty, int drop_num, int num_assigns) { 
	   double numeric_score; /* Will hold the numeric score */ 
	   /* The following two arrays are copies of the inputs that 
	    * will be edited. */ 
	   int copy_of_assigns[MAX_ASSIGN], copy_of_scores[MAX_ASSIGN]; 
	   double weight_total = 0.0; /* Will track weight total */ 
	   double sum_scores = 0.0; /* Will track sum of all scores */ 
	   int i; /* Used in for loops */ 
	 
	   for (i = 0; i < num_assigns; i++) { 
	      copy_of_assigns[i] = assigns[i]; 
	      copy_of_scores[i] = scores[i]; 
	   } 
	   for (i = 0; i < drop_num; i++) { 
	      int index_of_lowest = find_lowest(copy_of_assigns,  
	            scores, weights, num_assigns); 
 
	      copy_of_assigns[index_of_lowest] = 0; 
	 
	   } 
	   for (i = 0; i < num_assigns; i++) { 
	      if (copy_of_assigns[i] != 0) { 
	         int current = (scores[i] - (late_days[i] * penalty)); 
	 
	         if (current < 0) { 
	            copy_of_scores[i] = 0; 
	         } else { 
	            copy_of_scores[i] = current; 
	         } 
	         weight_total += weights[i]; 
	         sum_scores += (copy_of_scores[i] * weights[i]); 
	      } 
	   } 
	   numeric_score = (sum_scores / weight_total); 
	   return numeric_score; 
	} 
	 

	 
	void print_stats(int scores[MAX_ASSIGN], int late_days[MAX_ASSIGN], 
	                 int penalty, int number_assignments) { 
	   double mean, std_deviation, deviation_sum, variance; 
	   double mean_scores[MAX_ASSIGN]; 
	   double deviation_scores[MAX_ASSIGN]; 
	   int i; 
	   double mean_sum = 0.0; 
	 
	   for (i = 0; i < number_assignments; i++) { 
	      double current = scores[i] - (late_days[i] * penalty); 
	 
	      deviation_scores[i] = scores[i]; 
	      if (current < 0) { 
	         mean_scores[i] = 0; 
	      } else { 
	         mean_scores[i] = current; 
      } 
	      mean_sum += mean_scores[i]; 
	   } 
	   mean = (mean_sum / number_assignments); 
	 
	   deviation_sum = 0; 
	   for (i = 0; i < number_assignments; i++) { 
	      double current; 
	 
	      if ((deviation_scores[i] - (late_days[i] * penalty)) < 0) { 
	         current = 0.0; 
	      } else { 
	         current = (deviation_scores[i] - (late_days[i] * penalty)); 
	      } 
	      deviation_scores[i] = (current - mean); 
	      deviation_scores[i] = (deviation_scores[i] * deviation_scores[i]); 
	      deviation_sum += deviation_scores[i]; 
	   } 
	   variance = (deviation_sum / number_assignments); 
	   std_deviation = sqrt(variance); 
	   printf("Mean: %5.4f, Standard Deviation: %5.4f \n", mean, std_deviation); 
	 
	} 
	 
	int main() { 
	   int penalty_pts, to_drop, num_assignments, weight_total, i, j; 
	   int assignments[MAX_ASSIGN], scores[MAX_ASSIGN], weights[MAX_ASSIGN], 
	      days_late[MAX_ASSIGN]; 
	   char stats; 
	 
	   scanf("%d %d %c", &penalty_pts, &to_drop, &stats); 
	   scanf("%d", &num_assignments); 
	 
	   for (i = 0; i < num_assignments; i++) { 
	      scanf("%d, %d, %d, %d", &assignments[i], &scores[i], &weights[i], 
	            &days_late[i]); 
	   } 
	 
	   weight_total = 0; 
	   for (i = 0; i < num_assignments; i++) { 
	      weight_total += weights[i]; 
	   } 
	   if (weight_total != 100) { 
	      printf("ERROR: Invalid values provided\n"); 
	      return 1; 
	   } 
	 
	   printf("Numeric Score: %5.4f \n", 
	          calc_numeric(assignments, scores, weights, days_late, penalty_pts, 
	                       to_drop, num_assignments)); 
	 
	   printf("Points Penalty Per Day Late: %d\n", penalty_pts); 
	   printf("Number of Assignments Dropped: %d\n", to_drop); 
	   printf("Values Provided: \n"); 
	   printf("Assignment, Score, Weight, Days Late \n"); 
	 
	   for (i = 1; i <= num_assignments; i++) { 
	      for (j = 0; j < num_assignments; j++) { 
	         if (assignments[j] == i) { 
	            printf("%d, %d, %d, %d \n", assignments[j], scores[j], weights[j], 
	                   days_late[j]); 
	         } 
	      } 
	   } 
	 
	   if (stats == 'Y' || stats == 'y') { 
	      print_stats(scores, days_late, penalty_pts, num_assignments); 
	   } 
	   return 0; 
	 
	} 
